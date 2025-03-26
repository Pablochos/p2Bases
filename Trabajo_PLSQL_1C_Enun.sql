DROP TABLE detalle_pedido CASCADE CONSTRAINTS;
DROP TABLE pedidos CASCADE CONSTRAINTS;
DROP TABLE platos CASCADE CONSTRAINTS;
DROP TABLE personal_servicio CASCADE CONSTRAINTS;
DROP TABLE clientes CASCADE CONSTRAINTS;

DROP SEQUENCE seq_pedidos;


-- Creación de tablas y secuencias



create sequence seq_pedidos;

CREATE TABLE clientes (
    id_cliente INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    telefono VARCHAR2(20)
);

CREATE TABLE personal_servicio (
    id_personal INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    pedidos_activos INTEGER DEFAULT 0 CHECK (pedidos_activos <= 5)
);

CREATE TABLE platos (
    id_plato INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    disponible INTEGER DEFAULT 1 CHECK (DISPONIBLE in (0,1))
);

CREATE TABLE pedidos (
    id_pedido INTEGER PRIMARY KEY,
    id_cliente INTEGER REFERENCES clientes(id_cliente),
    id_personal INTEGER REFERENCES personal_servicio(id_personal),
    fecha_pedido DATE DEFAULT SYSDATE,
    total DECIMAL(10, 2) DEFAULT 0
);

CREATE TABLE detalle_pedido (
    id_pedido INTEGER REFERENCES pedidos(id_pedido),
    id_plato INTEGER REFERENCES platos(id_plato),
    cantidad INTEGER NOT NULL,
    PRIMARY KEY (id_pedido, id_plato)
);


-- Procedimiento corregido para registrar pedidos
create or replace procedure registrar_pedido(
    arg_id_cliente      INTEGER, 
    arg_id_personal     INTEGER, 
    arg_id_primer_plato INTEGER DEFAULT NULL,
    arg_id_segundo_plato INTEGER DEFAULT NULL
) is 
    -- Declaramos las variables que vamos a usar
    v_disponible INTEGER;
    v_pedidos_activos INTEGER;
    v_id_pedido INTEGER;
    v_total_pedido DECIMAL(10,2) := 0;
    v_precio_plato DECIMAL (10,2);
    
    -- Declaramos las excepciones que vamos a usar
    
    plato_no_disponible EXCEPTION;
    PRAGMA EXCEPTION_INIT(plato_no_disponible, -20001);
    
    no_hay_platos EXCEPTION;
    PRAGMA EXCEPTION_INIT(no_hay_platos, -20002);
    
    Personal_saturado EXCEPTION;
    PRAGMA EXCEPTION_INIT(Personal_saturado, -20003);
    
    plato_inexistente EXCEPTION;
    PRAGMA EXCEPTION_INIT(plato_inexistente, -20004);


BEGIN

    -- Verificar que han pedido al menos un plato.
    IF arg_id_primer_plato IS NULL AND arg_id_segundo_plato IS NULL THEN
        RAISE no_hay_platos;
    END IF;
    
    -- Comprobamos que el primer plato existe y si esta disponible
    IF arg_id_primer_plato IS NOT NULL THEN
        BEGIN
            -- Verificar si el plato está disponible
            SELECT disponible, precio  INTO v_disponible, v_precio_plato
            FROM platos
            WHERE id_plato = arg_id_primer_plato;
            
             -- Si el plato no está disponible, lanzar la excepción
            IF v_disponible = 0 THEN
                RAISE plato_no_disponible;
            END IF;
            
            -- Sumar el precio del plato al total
            v_total_pedido := v_total_pedido + v_precio_plato;
            
            EXCEPTION
            -- En caso de que no exista el plato se lanza se recoge la excepcion NO_DATA_FOUND
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20004, 'El primer plato seleccionado no existe.'); 
        END;
    END IF;
    
    -- Comprobamos que el segundo plato existe y si esta disponible
    IF arg_id_segundo_plato IS NOT NULL THEN
        BEGIN
            -- Verificar si el plato está disponible
            SELECT disponible, precio INTO v_disponible, v_precio_plato
            FROM platos
            WHERE id_plato = arg_id_segundo_plato;
            
            -- Si el plato no está disponible, lanzar la excepción
            IF v_disponible = 0 THEN
                RAISE plato_no_disponible;
            END IF;
            
            -- Sumar el precio del plato al total
            v_total_pedido := v_total_pedido + v_precio_plato;
            
            EXCEPTION
            -- En caso de que no exista el plato se lanza se recoge la excepcion NO_DATA_FOUND
                WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20004, 'El segundo plato seleccionado no existe.');
        END;
    END IF;
    

    -- Comprobar que el personal de servicio no tiene más de 5 pedidos activos
    BEGIN
        SELECT pedidos_activos INTO v_pedidos_activos
        FROM personal_servicio
        WHERE id_personal = arg_id_personal
        FOR UPDATE;
        
        IF v_pedidos_activos >= 5 THEN
            RAISE personal_saturado;
        END IF;
    END;
    
    -- Tras comprobar todo realizamos los inserts.
    
    -- Insertar pedido
    v_id_pedido := seq_pedidos.NEXTVAL;
    INSERT INTO pedidos (id_pedido, id_cliente, id_personal, fecha_pedido, total)
    VALUES (v_id_pedido, arg_id_cliente, arg_id_personal, SYSDATE, v_total_pedido);

    -- Insertar el plato 1 en el pedido
    IF arg_id_primer_plato IS NOT NULL THEN
        INSERT INTO detalle_pedido (id_pedido, id_plato, cantidad)
        VALUES (v_id_pedido, arg_id_primer_plato, 1);
    END IF;
    
    -- Insertar el plato 2 en el pedido
    IF arg_id_segundo_plato IS NOT NULL THEN
        INSERT INTO detalle_pedido (id_pedido, id_plato, cantidad)
        VALUES (v_id_pedido, arg_id_segundo_plato, 1);
    END IF;
    
    -- Actualizar pedidos activos en el personal
    UPDATE personal_servicio 
    SET pedidos_activos = pedidos_activos + 1 
    WHERE id_personal = arg_id_personal;

    -- Hacemos commit y liberamos el bloqueo en la linea del servicio
    COMMIT;

-- Bloque de excepciones
EXCEPTION

    WHEN plato_no_disponible THEN
        RAISE_APPLICATION_ERROR(-20001, 'Uno de los platos seleccionados no está disponible.');
        
    WHEN no_hay_platos THEN
        RAISE_APPLICATION_ERROR(-20002, 'El pedido debe contener al menos un plato');
        
    WHEN personal_saturado THEN
        RAISE_APPLICATION_ERROR(-20003, 'El personal de servicio tiene demasiados pedidos.');
        
    -- En caso de que sea una excepcion nueva o no controlada se recoge aqui
    WHEN OTHERS THEN
        ROLLBACK;  -- Siempre hacer rollback por si acaso
        RAISE;
END;
/

------ Respuestas a las preguntas:
-- * P4.1
-- Comprobamos el numero de pedidos activos que tiene el personal comprobando que no tiene 5 o mas pedidos activos, en caso contrario salta una excepcion y hacemos rollback.

-- * P4.2
-- Gracias a la linea For Update en el select de pedidos activos podemos bloquear la linea que indiquemos, el personal indicado en este caso, y asi asegurarnos que ningun otro usuario va a poder usar ese personal 
-- hasta que en nuestra trasaccion no hagamos un commit o un rollback

-- * P4.3
-- 

-- * P4.4
-- La implicación en el código sería que siempre saltaría la excepción ya que el número de platos siempre va a ser menor que 5 a mo ser que iniciemos la base de datos con al menos 6 platos por servidor.
-- En la gestion de excepciones siempre saltaria la misma que es la de personal_saturado ya que como hemos explicado antes al iniciar la base de datos disponemos de 0 platos asignados a cada servidor.
-- Ahora mismo si el if se cumple saltaria la excepcion de personal_saturado y si no se cumple sigue la ejecucion normalmente, ante la nueva condicion deberiamos cambiar de lugar la forma de hacerlo, osea
-- si la condicion se cumple el codigo va a continuar normalmente pero ne caso de que no se cumpla es cuando va a saltar la excepcion.

-- * P4.5
-- La estrategia es defensiva porque primero comprobamos todas las excepciones y posibles errores, y una vez que sabemos que todo está correcto es entonces cuando realizamos los inserts.

-- Procedimiento de test completo
create or replace
procedure reset_seq( p_seq_name varchar )
is
    l_val number;
begin
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/


create or replace procedure inicializa_test is
begin
    
    reset_seq('seq_pedidos');
        
  
    delete from Detalle_pedido;
    delete from Pedidos;
    delete from Platos;
    delete from Personal_servicio;
    delete from Clientes;
    
    -- Insertar datos de prueba
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (1, 'Pepe', 'Perez', '123456789');
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (2, 'Ana', 'Garcia', '987654321');
    
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (1, 'Carlos', 'Lopez', 0);
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (2, 'Maria', 'Fernandez', 5);
    
    insert into Platos (id_plato, nombre, precio, disponible) values (1, 'Sopa', 10.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (2, 'Pasta', 12.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (3, 'Carne', 15.0, 0);

    commit;
end;
/

exec inicializa_test;

-- Completa lost test, incluyendo al menos los del enunciado y añadiendo los que consideres necesarios

create or replace procedure test_registrar_pedido is
begin
    DBMS_OUTPUT.PUT_LINE('=== BATERÍA DE TESTS ===');
    
    -- Test 1: Probar pedido con primer y/o seguno plato disponibles y personal con capacidad
    begin
        
        DBMS_OUTPUT.PUT_LINE('--- CASO 1: PROBAR PRIMER Y/O SEGUNDO PLATO Y PERSONAL CON CAPACIDAD---');
    
        -- prueba 1. Probar pedido con ambos platos
        BEGIN
            registrar_pedido(1, 1, 1, 2); -- Cliente 1, Personal 1, Platos 1 y 2
            DBMS_OUTPUT.PUT_LINE('Éxito: Pedido completo registrado');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Fallo: ' || SQLERRM);
        END;
    
        -- prueba 2. Probar pedido solo con primer plato
        BEGIN
            registrar_pedido(2, 1, 1, NULL); -- Solo plato 1
            DBMS_OUTPUT.PUT_LINE('Éxito: Pedido solo primer plato registrado');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Fallo: ' || SQLERRM);
        END;
    
        -- prueba 3. Probar pedido solo con segundo plato
        BEGIN
            registrar_pedido(1, 1, NULL, 2); -- Solo plato 2
            DBMS_OUTPUT.PUT_LINE('Éxito: Pedido solo segundo plato registrado');

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Fallo: ' || SQLERRM);
        END;
    end;
    DBMS_OUTPUT.PUT_LINE('');
  
  -- Test 2: Pedido vacío - Debe devolver error -20002
    begin
        
        DBMS_OUTPUT.PUT_LINE('--- CASO 2: PROBAMOS PEDIDO VACÍO ---');
        registrar_pedido(1, 1, NULL, NULL);
        DBMS_OUTPUT.PUT_LINE('Fallo: ha registrado el pedido sin platos');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Exito: ' || SQLERRM);
    END;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 3: Plato no existe - Debe devolver error -20004
    -- Probamos con el primer plato
    begin 
        
        DBMS_OUTPUT.PUT_LINE('--- CASO 3: PLATO NO EXISTE ---');
        registrar_pedido(1, 1, 999, NULL); --Plato con ID 999 no existe
        DBMS_OUTPUT.PUT_LINE('Fallo: Ha creado un pedido con un plato inexistente');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Exito: ' || SQLERRM);
    END;
    
    -- Probamos con el segundo plato
    begin 
        
        registrar_pedido(1, 1, NULL, 999); --Plato con ID 999 no existe
        DBMS_OUTPUT.PUT_LINE('Fallo: Ha creado un pedido con un plato inexistente');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Exito: ' || SQLERRM);
    END;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 4: Plato no disponible (error -20001)
    BEGIN
        
        DBMS_OUTPUT.PUT_LINE('--- CASO 4: PLATO NO DISPONIBLE ---');
        registrar_pedido(1, 1, 3, NULL);
        DBMS_OUTPUT.PUT_LINE('Fallo: Ha creado un pedido con platos no disponibles');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Exito: ' || SQLERRM);
    END;
    DBMS_OUTPUT.PUT_LINE('');
    
     -- Test 5: Personal con 5 pedidos
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- CASO 5: PERSONAL DE SERVICIO LLENO --');
        registrar_pedido(1, 2, 1, NULL); -- Personal 2 tiene 5 pedidos
        DBMS_OUTPUT.PUT_LINE('Fallo: Ha asignado un pedido a un personal de servicio saturado');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Exito: ' || SQLERRM);
    END;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 6: Comprobar que en un pedido de varios platos el precio es correcto
    DECLARE
        v_total_pedido DECIMAL(10,2) := 0;
    BEGIN
        inicializa_test();
        DBMS_OUTPUT.PUT_LINE('--- CASO 6: COMPROBAR PRECIO TOTAL --');
        registrar_pedido(1, 1, 1, 2); -- Uso un plato que cuesta 10 y otro que cuesta 12
        
        SELECT total INTO v_total_pedido
        FROM pedidos
        WHERE id_cliente = 1 AND id_personal = 1;
        
        IF v_total_pedido = 22 THEN
            DBMS_OUTPUT.PUT_LINE('Exito: Se calcula bien el total de los platos');
        ELSE
        
            DBMS_OUTPUT.PUT_LINE('Fallo: No se ha calculado bien el total de los platos');
        END IF;

    END;
  
end;
/

set serveroutput on;
exec test_registrar_pedido;

