-- Procedimiento corregido para registrar pedidos
create or replace procedure registrar_pedido(
    arg_id_cliente      INTEGER, 
    arg_id_personal     INTEGER, 
    arg_id_primer_plato INTEGER DEFAULT NULL,
    arg_id_segundo_plato INTEGER DEFAULT NULL
) is 
    v_pedidos_activos INTEGER;
    v_total_pedido DECIMAL(10,2) := 0;
    v_id_pedido INTEGER;
    v_primer_plato_disponible BOOLEAN;
    v_segundo_plato_disponible BOOLEAN;

    -- Excepciones
    plato_no_disponible EXCEPTION;
    PRAGMA EXCEPTION_INIT(plato_no_disponible, -20001);
    no_hay_platos EXCEPTION;
    PRAGMA EXCEPTION_INIT(no_hay_platos, -20002);
    Personal_saturado EXCEPTION;
    PRAGMA EXCEPTION_INIT(Personal_saturado, -20003);
    primer_plato_inexsistente EXCEPTION;
    PRAGMA EXCEPTION_INIT(primer_plato_inexsistente, -20004);
    segundo_plato_inexsistente EXCEPTION;
    PRAGMA EXCEPTION_INIT(segundo_plato_inexsistente, -20004);

BEGIN
    -- Verificar al menos un plato
    IF arg_id_primer_plato IS NULL AND arg_id_segundo_plato IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'El pedido debe contener al menos un plato.');
    END IF;

    -- Bloquear fila del personal para evitar concurrencia
    SELECT pedidos_activos INTO v_pedidos_activos 
    FROM personal_servicio 
    WHERE id_personal = arg_id_personal
    FOR UPDATE; -- Bloqueo explícito

    -- Verificar límite de pedidos
    IF v_pedidos_activos >= 5 THEN
        RAISE_APPLICATION_ERROR(-20003, 'El personal de servicio tiene demasiados pedidos.');
    END IF;

    -- Comprobar platos
    IF arg_id_primer_plato IS NOT NULL THEN
        BEGIN
            SELECT disponible INTO v_primer_plato_disponible 
            FROM platos 
            WHERE id_plato = arg_id_primer_plato
            FOR UPDATE; -- Bloqueo para concurrencia
            IF NOT v_primer_plato_disponible THEN
                RAISE plato_no_disponible;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20004, 'El primer plato seleccionado no existe.');
        END;
    END IF;

    IF arg_id_segundo_plato IS NOT NULL THEN
        BEGIN
            SELECT disponible INTO v_segundo_plato_disponible 
            FROM platos 
            WHERE id_plato = arg_id_segundo_plato
            FOR UPDATE; -- Bloqueo para concurrencia
            IF NOT v_segundo_plato_disponible THEN
                RAISE plato_no_disponible;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20004, 'El segundo plato seleccionado no existe.');
        END;
    END IF;

    -- Insertar pedido
    v_id_pedido := seq_pedidos.NEXTVAL;
    INSERT INTO pedidos (id_pedido, id_cliente, id_personal, fecha_pedido, total)
    VALUES (v_id_pedido, arg_id_cliente, arg_id_personal, SYSDATE, v_total_pedido);

    -- Insertar detalles
    IF arg_id_primer_plato IS NOT NULL THEN
        INSERT INTO detalle_pedido (id_pedido, id_plato, cantidad)
        VALUES (v_id_pedido, arg_id_primer_plato, 1);
    END IF;

    IF arg_id_segundo_plato IS NOT NULL THEN
        INSERT INTO detalle_pedido (id_pedido, id_plato, cantidad)
        VALUES (v_id_pedido, arg_id_segundo_plato, 1);
    END IF;

    -- Actualizar pedidos activos
    UPDATE personal_servicio 
    SET pedidos_activos = pedidos_activos + 1 
    WHERE id_personal = arg_id_personal;

    COMMIT;

EXCEPTION
    WHEN plato_no_disponible THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, 'Uno de los platos seleccionados no está disponible.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

------ Respuestas a las preguntas:
-- * P4.1
-- Se utiliza FOR UPDATE al consultar pedidos_activos para bloquear la fila, evitando que otras transacciones modifiquen el valor hasta que se complete la transacción actual.

-- * P4.2
-- El bloqueo (FOR UPDATE) garantiza que solo una transacción pueda actualizar pedidos_activos a la vez. Otras transacciones esperan hasta que se libere el bloqueo.

-- * P4.3
-- No completamente. Aunque se usan bloqueos, en entornos altamente concurrentes, se recomienda usar SERIALIZABLE o manejar reintentos para garantizar consistencia.

-- * P4.4
-- La restricción CHECK sería redundante. Se debe capturar ORA-02290 y convertirla en -20003. Ejemplo:
-- EXCEPTION WHEN OTHERS THEN
--     IF SQLCODE = -2290 THEN RAISE_APPLICATION_ERROR(-20003, ...);

-- * P4.5
-- Estrategia defensiva: Validaciones manuales + bloqueos. Se evitan inconsistencias con FOR UPDATE y transacciones atómicas.

-- Procedimiento de test completo
create or replace procedure test_registrar_pedido is
begin
    -- Caso 1: Pedido válido
    BEGIN
        inicializa_test;
        registrar_pedido(1, 1, 1, 2);
        DBMS_OUTPUT.PUT_LINE('Caso 1: OK');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Caso 1: ERROR - ' || SQLERRM);
    END;

    -- Caso 2: Pedido vacío
    BEGIN
        inicializa_test;
        registrar_pedido(1, 1);
        DBMS_OUTPUT.PUT_LINE('Caso 2: ERROR - No lanzó excepción');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20002 THEN
                DBMS_OUTPUT.PUT_LINE('Caso 2: OK');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Caso 2: ERROR - ' || SQLERRM);
            END IF;
    END;

    -- Caso 3: Plato no existe
    BEGIN
        inicializa_test;
        registrar_pedido(1, 1, 99);
        DBMS_OUTPUT.PUT_LINE('Caso 3: ERROR - No lanzó excepción');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20004 THEN
                DBMS_OUTPUT.PUT_LINE('Caso 3: OK');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Caso 3: ERROR - ' || SQLERRM);
            END IF;
    END;

    -- Caso 4: Personal saturado
    BEGIN
        inicializa_test;
        registrar_pedido(1, 2, 1);
        DBMS_OUTPUT.PUT_LINE('Caso 4: ERROR - No lanzó excepción');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20003 THEN
                DBMS_OUTPUT.PUT_LINE('Caso 4: OK');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Caso 4: ERROR - ' || SQLERRM);
            END IF;
    END;

    -- Caso 5: Plato no disponible
    BEGIN
        inicializa_test;
        registrar_pedido(1, 1, 3);
        DBMS_OUTPUT.PUT_LINE('Caso 5: ERROR - No lanzó excepción');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20001 THEN
                DBMS_OUTPUT.PUT_LINE('Caso 5: OK');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Caso 5: ERROR - ' || SQLERRM);
            END IF;
    END;
END;
/

set serveroutput on;
exec test_registrar_pedido;