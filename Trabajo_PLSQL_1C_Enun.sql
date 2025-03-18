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
    disponible BOOLEAN DEFAULT TRUE
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


	
-- Procedimiento a implementar para realizar la reserva
create or replace procedure registrar_pedido(
    arg_id_cliente      INTEGER, 
    arg_id_personal     INTEGER, 
    arg_id_primer_plato INTEGER DEFAULT NULL,
    arg_id_segundo_plato INTEGER DEFAULT NULL
) is 
    plato_no_disponible exception;
    pragma exception_init(plato_no_disponible, -20001);
    msg_plato_no_disponible constant varchar(50) := 'Uno de los platos seleccionados no esta disponible';
    
    no_hay_platos exception;
    pragma exception_init(no_hay_platos, -20002);
    msg_no_hay_platos constant varchar(50) := 'El pedido debe contener al menos un plato';
    
    Personal_saturado exception;
    pragma exception_init(Personal_saturado, -20003);
    msg_Personal_saturado constant varchar(50) := 'El personal de servicio tiene demasiados pedidos.';
    
    primer_plato_inexsistente exception;
    pragma exception_init(primer_plato_inexsistente, -20004);
    msg_primer_plato_inexsistente constant varchar(50) := 'El primer plato seleccionado no existe';
    
    segundo_plato_inexsistente exception;
    pragma exception_init(segundo_plato_inexsistente, -20004);
    msg_segundo_plato_inexsistente constant varchar(50) := 'El segundo plato seleccionado no existe';
 begin
 
 --Comprobamos que al menos se ha seleccionado un plato.
    IF arg_id_primer_plato IS NULL AND arg_id_segundo_plato IS NULL THEN
        --lanzamos la excepción con el código -20002.
        RAISE no_hay_platos;
    END IF;

-- Comprobar que el personal de servicio no tiene más de 5 pedidos activos.
    -- Si el personal tiene mas de 5 pedidos activos salta una excepción.
    SELECT pedidos_activos INTO v_pedidos_activos
    FROM personal_servicio
    WHERE id_personal = arg_id_personal;

    IF v_pedidos_activos >= 5 THEN
        -- Lanzamos la excepción del código -20003.
        RAISE personal_saturado;
    END IF;
    
 -- Comprobamos la disponibilidad y existencia del primer plato. 
 -- Si no hay existencias del primer plato seleccionado o no esta disponible en estos momentos salta la excepcion.
    IF arg_id_primer_plato IS NOT NULL THEN
        BEGIN
            SELECT disponible INTO v_primer_plato_disponible
            FROM platos
            WHERE id_plato = arg_id_primer_plato;
            
            IF NOT v_primer_plato_disponible THEN
                RAISE plato_no_disponible;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Lanzamos la excepción con el código -20004.
                RAISE primer_plato_inexsistente;
        END;
    END IF;
    
     -- Comprobamos disponibilidad y existencia del segundo plato, al igual que hemos hecho con los primeros platos
     -- Si no hay existencias del segundo plato seleccionado o no esta disponible en estos momentos salta la excepción.
    IF arg_id_segundo_plato IS NOT NULL THEN
        BEGIN
            SELECT disponible INTO v_segundo_plato_disponible
            FROM platos
            WHERE id_plato = arg_id_segundo_plato;
            
            IF NOT v_segundo_plato_disponible THEN
                RAISE plato_no_disponible;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Lanzamos la excepción con el código -20004.
                 RAISE segundo_plato_inexsistente;
        END;
    END IF;
     
  -- Calcular el total del pedido
    IF arg_id_primer_plato IS NOT NULL THEN
        SELECT precio INTO v_total_pedido
        FROM platos
        WHERE id_plato = arg_id_primer_plato;
    END IF;

    IF arg_id_segundo_plato IS NOT NULL THEN
        DECLARE
            v_precio_segundo_plato DECIMAL(10, 2);
        BEGIN
            -- Obtener el precio del segundo plato
            SELECT precio INTO v_precio_segundo_plato
            FROM platos
            WHERE id_plato = arg_id_segundo_plato;

            -- Sumar el precio del segundo plato al total
            v_total_pedido := v_total_pedido + v_precio_segundo_plato;
        END;
    END IF;
end;
/

------ Deja aquí tus respuestas a las preguntas del enunciado:
-- NO SE CORREGIRÁN RESPUESTAS QUE NO ESTÉN AQUÍ (utiliza el espacio que necesites apra cada una)
-- * P4.1 En el código actual, se garantiza que el personal no supere el límite de 5 
--        pedidos activos mediante una consulta a la tabla personal_servicio para obtener 
--        el valor de pedidos_activos. Si este valor es >= 5, se lanza la excepción -20003.
--
-- * P4.2 
--
-- * P4.3
--
-- * P4.4
--
-- * P4.5
-- 


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
    
    insert into Platos (id_plato, nombre, precio, disponible) values (1, 'Sopa', 10.0, TRUE);
    insert into Platos (id_plato, nombre, precio, disponible) values (2, 'Pasta', 12.0, TRUE);
    insert into Platos (id_plato, nombre, precio, disponible) values (3, 'Carne', 15.0, FALSE);

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