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
  --caso 1 Pedido correct, se realiza
  
  -- Test 2: Pedido vacío - Debe devolver error -20002
    begin
    inicializa_test;
        DBMS_OUTPUT.PUT_LINE('--- CASO: PROBAMOS PEDIDO VACÍO ---');
        registrar_pedido(1, 1, NULL, NULL);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Resultado: ' || SQLERRM);
    END;
    
    -- Test 3: Plato no existe - Debe devolver error -20004
    begin 
        inicializa_test;
        DBMS_OUTPUT.PUT_LINE('--- CASO: PLATO NO EXISTE ---');
        registrar_pedido(1, 1, 999, NULL); --Plato con ID 999 no existe
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Resultado: ' || SQLERRM);
    END;

  
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

