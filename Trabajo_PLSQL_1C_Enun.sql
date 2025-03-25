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
            SELECT disponible INTO v_disponible
            FROM platos
            WHERE id_plato = arg_id_primer_plato;
            
             -- Si el plato no está disponible, lanzar la excepción
            IF v_disponible = 0 THEN
                RAISE plato_no_disponible;
            END IF;
            
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
            SELECT disponible INTO v_disponible
            FROM platos
            WHERE id_plato = arg_id_segundo_plato;
            
            -- Si el plato no está disponible, lanzar la excepción
            IF v_disponible = 0 THEN
                RAISE plato_no_disponible;
            END IF;
            
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
-- Comprobamos el numero de pedidos activos que tiene el personal indicado para ese pedido, si no es 5 o superior entonces no salta la excepcion y no se para la transaccion.
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
	 
  --caso 1 Pedido correct, se realiza
  begin
    inicializa_test;
  end;
  
  -- Idem para el resto de casos

  /* - Si se realiza un pedido vac´ıo (sin platos) devuelve el error -200002.
     - Si se realiza un pedido con un plato que no existe devuelve en error -20004.
     - Si se realiza un pedido que incluye un plato que no est´a ya disponible devuelve el error -20001.
     - Personal de servicio ya tiene 5 pedidos activos y se le asigna otro pedido devuelve el error -20003
     - ... los que os puedan ocurrir que puedan ser necesarios para comprobar el correcto funcionamiento del procedimiento
*/
  
end;
/

set serveroutput on;
exec test_registrar_pedido;

