#Crear la base de datos
create database salud_viva;
use salud_viva;

#Tabla de especialidades médicas
create table especialidades (
    id_especialidad int auto_increment primary key,
    nombre_especialidad varchar(100) not null unique,
    descripcion text
);

#Tabla de médicos
create table medicos (
    id_medico int auto_increment primary key,
    nombre varchar(100) not null,
    apellido varchar(100) not null,
    id_especialidad int not null,
    telefono varchar(15),
    correo varchar(100) unique,
    foreign key (id_especialidad) references especialidades(id_especialidad)
);

#Tabla de pacientes
create table pacientes (
    id_paciente int auto_increment primary key,
    nombre varchar(100) not null,
    apellido varchar(100) not null,
    identificacion varchar(15) not null,
    telefono varchar(15),
    correo varchar(100) unique,
    eps varchar(50) not null
);

#Tabla de citas
create table citas (
    id_cita int auto_increment primary key,
    id_paciente int not null,
    id_medico int not null,
    fecha_hora datetime not null,
    estado enum('programada', 'completada', 'cancelada') default 'programada',
    motivo text,
    fecha_creacion timestamp default current_timestamp,
    unique key unique_medico_hora (id_medico, fecha_hora),
    foreign key (id_paciente) references pacientes(id_paciente),
    foreign key (id_medico) references medicos(id_medico)
);

#Tabla de auditoría para cambios en citas
create table auditoria_citas (
    id_auditoria int auto_increment primary key,
    id_cita int not null,
    accion enum('creación', 'modificación', 'cancelación') not null,
    fecha_hora_anterior datetime,
    fecha_hora_nueva datetime,
    estado_anterior enum('programada', 'completada', 'cancelada'),
    estado_nuevo enum('programada', 'completada', 'cancelada'),
    usuario varchar(100) not null,
    fecha_cambio timestamp default current_timestamp,
    foreign key (id_cita) references citas(id_cita)
); 

#Trigger para evitar citas duplicadas (médico y hora)
DELIMITER //

CREATE TRIGGER before_cita_insert
BEFORE INSERT ON citas
FOR EACH ROW
BEGIN
    DECLARE cita_count INT;
    
    #validar si ya existe una cita para el mismo médico en la misma fecha y hora
    SELECT COUNT(*) INTO cita_count 
    FROM citas 
    WHERE id_medico = NEW.id_medico 
    AND fecha_hora = NEW.fecha_hora
    AND estado != 'cancelada';
    
    IF cita_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El médico ya tiene una cita programada en esta fecha y hora';
    END IF;
END//

#Trigger para registrar creación de citas en auditoría
CREATE TRIGGER after_cita_insert
AFTER INSERT ON citas
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_citas (
        id_cita, 
        accion, 
        fecha_hora_nueva, 
        estado_nuevo, 
        usuario
    ) VALUES (
        NEW.id_cita,
        'creación',
        NEW.fecha_hora,
        NEW.estado,
        CURRENT_USER()
    );
END//

#Trigger para registrar modificaciones de citas en auditoría
CREATE TRIGGER after_cita_update
AFTER UPDATE ON citas
FOR EACH ROW
BEGIN
    IF OLD.fecha_hora != NEW.fecha_hora OR OLD.estado != NEW.estado THEN
        INSERT INTO auditoria_citas (
            id_cita, 
            accion, 
            fecha_hora_anterior, 
            fecha_hora_nueva, 
            estado_anterior, 
            estado_nuevo, 
            usuario
        ) VALUES (
            NEW.id_cita,
            'modificación',
            OLD.fecha_hora,
            NEW.fecha_hora,
            OLD.estado,
            NEW.estado,
            CURRENT_USER()
        );
    END IF;
END//

DELIMITER ;

#Insertar especialidades
INSERT INTO especialidades (nombre_especialidad, descripcion) VALUES
('Cardiología', 'Especialidad en enfermedades del corazón'),
('Dermatología', 'Especialidad en enfermedades de la piel'),
('Pediatría', 'Especialidad en salud infantil');

#Insertar médicos
INSERT INTO medicos (nombre, apellido, id_especialidad, telefono, correo) VALUES
('Carlos', 'Gómez', 1, '3001234567', 'c.gomez@clinica.com'),
('Ana', 'López', 2, '3002345678', 'a.lopez@clinica.com'),
('Miguel', 'Rodríguez', 3, '3003456789', 'm.rodriguez@clinica.com');

#Insertar pacientes
INSERT INTO pacientes (nombre, apellido, identificacion, telefono, correo, eps) VALUES
('María', 'García', '69564248', '3101234567', 'maria.garcia@email.com', 'Nueva EPS'),
('José', 'Martínez', '11668597543', '3202345678', 'jose.martinez@email.com', 'Emssanar'),
('Laura', 'Hernández', '54871300', '3153456789', 'laura.hernandez@email.com', 'Emssanar');

#Insertar citas
INSERT INTO citas (id_paciente, id_medico, fecha_hora, motivo) VALUES
(1, 1, '2023-11-20 10:00:00', 'Dolor en el pecho'),
(2, 2, '2023-11-20 11:30:00', 'Consulta por erupción cutánea'),
(3, 3, '2023-11-21 09:00:00', 'Control niño sano');

#1. Especialidad más solicitada
SELECT e.nombre_especialidad, COUNT(c.id_cita) as total_citas
FROM especialidades e
JOIN medicos m ON e.id_especialidad = m.id_especialidad
JOIN citas c ON m.id_medico = c.id_medico
WHERE c.estado != 'cancelada'
GROUP BY e.id_especialidad
ORDER BY total_citas DESC
LIMIT 1;

#2. Pacientes con más citas
SELECT p.nombre, p.apellido, COUNT(c.id_cita) as total_citas
FROM pacientes p
JOIN citas c ON p.id_paciente = c.id_paciente
WHERE c.estado != 'cancelada'
GROUP BY p.id_paciente
ORDER BY total_citas DESC;

#3. Historial de cambios de una cita específica
SELECT ac.accion, ac.fecha_hora_anterior, ac.fecha_hora_nueva, 
       ac.estado_anterior, ac.estado_nuevo, ac.usuario, ac.fecha_cambio
FROM auditoria_citas ac
WHERE ac.id_cita = 1  -- Reemplazar con el ID de cita deseado
ORDER BY ac.fecha_cambio DESC;

#4. Médicos y su cantidad de citas programadas
SELECT m.nombre, m.apellido, e.nombre_especialidad, 
       COUNT(c.id_cita) as citas_programadas
FROM medicos m
JOIN especialidades e ON m.id_especialidad = e.id_especialidad
LEFT JOIN citas c ON m.id_medico = c.id_medico AND c.estado = 'programada'
GROUP BY m.id_medico
ORDER BY citas_programadas DESC;

#5. Citas canceladas por mes
SELECT YEAR(fecha_hora) as año, MONTH(fecha_hora) as mes, 
       COUNT(id_cita) as citas_canceladas
FROM citas
WHERE estado = 'cancelada'
GROUP BY YEAR(fecha_hora), MONTH(fecha_hora)
ORDER BY año, mes;

#Intentar crear una cita duplicada (debe fallar)
INSERT INTO citas (id_paciente, id_medico, fecha_hora, motivo) 
VALUES (1, 1, '2023-11-20 10:00:00', 'Segunda cita misma hora');

#Modificar una cita (debe generar registro de auditoría)
UPDATE citas 
SET fecha_hora = '2023-11-20 10:30:00' 
WHERE id_cita = 1;

#Cancelar una cita (debe generar registro de auditoría)
UPDATE citas 
SET estado = 'cancelada' 
WHERE id_cita = 2;

#Ver registros de auditoría
SELECT * FROM auditoria_citas;