-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 24-02-2026 a las 20:35:15
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `prueba_tecnica`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_generate_credit_note` (IN `p_document_id` INT, IN `p_user_id` INT)   BEGIN
    -- Generar la Nota de Crédito
    INSERT INTO credit_notes (parent_invoice_id, issue_date, status)
    VALUES (p_document_id, CURRENT_DATE, 'EMITIDO');
    
    -- Actualizar el estado de la factura padre
    UPDATE invoices SET status = 'NC_APLICADA' WHERE id = p_document_id;
    
    -- Registrar en tabla de auditoría
    INSERT INTO fe_audit_log (document_id, action, old_status, new_status, user_id)
    VALUES (p_document_id, 'GENERADO_NOTA_CREDITO', 'EMITIDO', 'NC_APLICADA', p_user_id);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_generate_libreta_dataset` (IN `p_section_id` INT, IN `p_exam_id` INT)   BEGIN
    -- LONGTEXT para evitar problemas de tamaño con el JSON
    DECLARE v_cache LONGTEXT; 

    -- Aumentamos el límite de la sesión actual para evitar que el JSON del aula se rompa a la mitad.
    SET SESSION group_concat_max_len = 1000000;

    -- 1. Intentar leer de la caché válida
    SELECT payload INTO v_cache FROM pdf_cache 
    WHERE section_id = p_section_id AND exam_id = p_exam_id AND is_valid = TRUE;

    -- 2. Si no hay caché o fue invalidada, hacer la consulta pesada
    IF v_cache IS NULL THEN
        
        SELECT CONCAT('[', 
            GROUP_CONCAT(
                CONCAT('{"student_id":', student_id, ',"name":"', name, '","grades_data":', grades_data, '}') 
                SEPARATOR ','
            ), 
        ']') INTO v_cache
        FROM view_libreta_dataset 
        WHERE section_id = p_section_id AND exam_id = p_exam_id;
        
        -- Guardar 
        INSERT INTO pdf_cache (section_id, exam_id, payload, is_valid)
        VALUES (p_section_id, p_exam_id, v_cache, TRUE)
        ON DUPLICATE KEY UPDATE 
            payload = VALUES(payload), 
            is_valid = TRUE;
    END IF;
    
    -- 3. Retornar el datos JSON
    SELECT v_cache AS dataset_json;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_area_unit_and_annual_grades` (IN `p_student_id` INT)   BEGIN
    SELECT 
        area_id,
        MAX(CASE WHEN unit_id = 1 THEN unit_average END) AS unit_1,
        MAX(CASE WHEN unit_id = 2 THEN unit_average END) AS unit_2,
        MAX(CASE WHEN unit_id = 3 THEN unit_average END) AS unit_3,
        MAX(CASE WHEN unit_id = 4 THEN unit_average END) AS unit_4,
        fn_promedio_ponderado(area_id, p_student_id) AS annual_grade 
    FROM view_unidad_promedio
    WHERE student_id = p_student_id
    GROUP BY area_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_normalize_invoice_data` ()   BEGIN
    DELETE FROM invoices 
    WHERE id NOT IN (
        SELECT max_id FROM (
            SELECT MAX(id) as max_id FROM invoices GROUP BY invoice_number
        ) AS temp
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_process_void_request` (IN `p_document_id` INT, IN `p_user_id` INT)   BEGIN
    DECLARE v_days_elapsed INT;
    DECLARE v_status VARCHAR(20);
    
    SELECT days_elapsed, status INTO v_days_elapsed, v_status 
    FROM view_document_status WHERE document_id = p_document_id;

    IF v_status IN ('ANULADO', 'NC_APLICADA') THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'El documento ya está anulado o tiene nota de crédito.';
    END IF;

    IF v_days_elapsed > 7 THEN
        -- Nota de Crédito
        CALL sp_generate_credit_note(p_document_id, p_user_id);
    ELSE
        -- baja directa
        UPDATE invoices SET status = 'ANULADO' WHERE id = p_document_id;
        
        INSERT INTO fe_audit_log (document_id, action, old_status, new_status, user_id)
        VALUES (p_document_id, 'ANULACION_DIRECTA', v_status, 'ANULADO', p_user_id);
    END IF;
END$$

--
-- Funciones
--
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_promedio_ponderado` (`p_area_id` INT, `p_student_id` INT) RETURNS INT(11) DETERMINISTIC BEGIN
    DECLARE v_promedio DECIMAL(10,2);
    DECLARE v_nota_final INT;
    
    -- 1. Calculamos el promedio exacto con decimales
    SELECT SUM(g.grade * c.weight) / SUM(c.weight) INTO v_promedio
    FROM grades g
    JOIN courses c ON g.course_id = c.id
    WHERE c.area_id = p_area_id AND g.student_id = p_student_id;
    
    -- 2. Aplicamos redondeo
    SET v_nota_final = LEAST(GREATEST(ROUND(IFNULL(v_promedio, 0), 0), 0), 20);
    
    RETURN v_nota_final;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `areas`
--

CREATE TABLE `areas` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `areas`
--

INSERT INTO `areas` (`id`, `name`) VALUES
(1, 'Matemáticas'),
(2, 'Ciencia y Tecnología'),
(3, 'Comunicación');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `classrooms`
--

CREATE TABLE `classrooms` (
  `id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `classrooms`
--

INSERT INTO `classrooms` (`id`, `name`) VALUES
(1, 'Aula 101'),
(2, 'Aula 301'),
(3, 'Aula 501');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `courses`
--

CREATE TABLE `courses` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `area_id` int(11) NOT NULL,
  `weight` decimal(5,2) DEFAULT 1.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `courses`
--

INSERT INTO `courses` (`id`, `name`, `area_id`, `weight`) VALUES
(1, 'Álgebra', 1, 4.00),
(2, 'Aritmética', 1, 3.00),
(3, 'Física', 2, 3.00),
(4, 'Biología', 2, 2.00),
(5, 'Lenguaje', 3, 4.00),
(6, 'Literatura', 3, 3.00);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `credit_notes`
--

CREATE TABLE `credit_notes` (
  `id` int(11) NOT NULL,
  `parent_invoice_id` int(11) NOT NULL,
  `issue_date` date NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'ISSUED'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `credit_notes`
--

INSERT INTO `credit_notes` (`id`, `parent_invoice_id`, `issue_date`, `status`) VALUES
(1, 4, '2026-02-24', 'EMITIDO');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `fe_audit_log`
--

CREATE TABLE `fe_audit_log` (
  `audit_id` int(11) NOT NULL,
  `document_id` int(11) NOT NULL,
  `action` varchar(50) NOT NULL,
  `old_status` varchar(20) DEFAULT NULL,
  `new_status` varchar(20) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `fe_audit_log`
--

INSERT INTO `fe_audit_log` (`audit_id`, `document_id`, `action`, `old_status`, `new_status`, `user_id`, `created_at`) VALUES
(1, 4, 'GENERADO_NOTA_CREDITO', 'EMITIDO', 'NC_APLICADA', 999, '2026-02-24 15:40:35'),
(2, 1, 'ANULACION_DIRECTA', 'EMITIDO', 'ANULADO', 999, '2026-02-24 15:41:58');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `grades`
--

CREATE TABLE `grades` (
  `id` int(11) NOT NULL,
  `student_id` int(11) NOT NULL,
  `course_id` int(11) NOT NULL,
  `unit_id` int(11) NOT NULL,
  `exam_id` int(11) NOT NULL,
  `grade` decimal(5,2) NOT NULL,
  `is_active` tinyint(1) DEFAULT 1
) ;

--
-- Volcado de datos para la tabla `grades`
--

INSERT INTO `grades` (`id`, `student_id`, `course_id`, `unit_id`, `exam_id`, `grade`, `is_active`) VALUES
(1, 1, 1, 1, 1, 14.50, 1),
(2, 1, 3, 1, 1, 12.00, 1),
(3, 1, 5, 1, 1, 16.00, 1),
(4, 2, 1, 1, 1, 18.00, 1),
(5, 2, 3, 1, 1, 17.50, 1),
(6, 2, 5, 1, 1, 19.00, 1),
(7, 3, 1, 1, 1, 10.50, 1),
(8, 3, 3, 1, 1, 9.50, 1),
(9, 3, 5, 1, 1, 11.00, 1),
(10, 4, 1, 1, 1, 20.00, 1),
(11, 4, 3, 1, 1, 19.00, 1),
(12, 4, 5, 1, 1, 18.50, 1),
(13, 5, 1, 1, 1, 13.00, 1),
(14, 5, 3, 1, 1, 14.00, 1),
(15, 5, 5, 1, 1, 13.50, 1),
(16, 6, 1, 1, 1, 16.00, 1),
(17, 6, 3, 1, 1, 15.50, 1),
(18, 6, 5, 1, 1, 17.00, 1),
(19, 7, 1, 1, 1, 11.50, 1),
(20, 7, 3, 1, 1, 10.50, 1),
(21, 7, 5, 1, 1, 12.00, 1),
(22, 8, 1, 1, 1, 19.50, 1),
(23, 8, 3, 1, 1, 18.00, 1),
(24, 8, 5, 1, 1, 20.00, 1),
(25, 9, 1, 1, 1, 14.00, 1),
(26, 9, 3, 1, 1, 13.00, 1),
(27, 9, 5, 1, 1, 12.50, 1),
(28, 10, 1, 1, 1, 17.50, 1),
(29, 10, 3, 1, 1, 16.50, 1),
(30, 10, 5, 1, 1, 18.00, 1),
(31, 11, 1, 1, 1, 8.50, 1),
(32, 11, 3, 1, 1, 10.00, 1),
(33, 11, 5, 1, 1, 9.50, 1),
(34, 12, 1, 1, 1, 18.50, 1),
(35, 12, 3, 1, 1, 19.00, 1),
(36, 12, 5, 1, 1, 17.50, 1),
(37, 13, 1, 1, 1, 12.50, 1),
(38, 13, 3, 1, 1, 14.00, 1),
(39, 13, 5, 1, 1, 15.00, 1),
(40, 14, 1, 1, 1, 15.00, 1),
(41, 14, 3, 1, 1, 16.50, 1),
(42, 14, 5, 1, 1, 16.00, 1),
(43, 15, 1, 1, 1, 13.50, 1),
(44, 15, 3, 1, 1, 14.50, 1),
(45, 15, 5, 1, 1, 13.00, 1),
(46, 1, 1, 2, 2, 15.50, 1),
(47, 1, 3, 2, 2, 13.00, 1),
(48, 1, 5, 2, 2, 17.00, 1),
(49, 2, 1, 2, 2, 19.00, 1),
(50, 2, 3, 2, 2, 18.50, 1),
(51, 2, 5, 2, 2, 20.00, 1),
(52, 3, 1, 2, 2, 11.50, 1),
(53, 3, 3, 2, 2, 10.50, 1),
(54, 3, 5, 2, 2, 12.00, 1),
(55, 4, 1, 2, 2, 19.50, 1),
(56, 4, 3, 2, 2, 19.50, 1),
(57, 4, 5, 2, 2, 19.00, 1),
(58, 5, 1, 2, 2, 14.00, 1),
(59, 5, 3, 2, 2, 14.50, 1),
(60, 5, 5, 2, 2, 15.00, 1),
(61, 6, 1, 2, 2, 17.00, 1),
(62, 6, 3, 2, 2, 16.00, 1),
(63, 6, 5, 2, 2, 18.00, 1),
(64, 7, 1, 2, 2, 12.50, 1),
(65, 7, 3, 2, 2, 11.00, 1),
(66, 7, 5, 2, 2, 13.00, 1),
(67, 8, 1, 2, 2, 20.00, 1),
(68, 8, 3, 2, 2, 19.00, 1),
(69, 8, 5, 2, 2, 20.00, 1),
(70, 9, 1, 2, 2, 15.00, 1),
(71, 9, 3, 2, 2, 14.00, 1),
(72, 9, 5, 2, 2, 13.50, 1),
(73, 10, 1, 2, 2, 18.00, 1),
(74, 10, 3, 2, 2, 17.00, 1),
(75, 10, 5, 2, 2, 19.00, 1),
(76, 11, 1, 2, 2, 10.50, 1),
(77, 11, 3, 2, 2, 11.00, 1),
(78, 11, 5, 2, 2, 10.50, 1),
(79, 12, 1, 2, 2, 19.00, 1),
(80, 12, 3, 2, 2, 19.50, 1),
(81, 12, 5, 2, 2, 18.00, 1),
(82, 13, 1, 2, 2, 13.50, 1),
(83, 13, 3, 2, 2, 15.00, 1),
(84, 13, 5, 2, 2, 16.00, 1),
(85, 14, 1, 2, 2, 16.00, 1),
(86, 14, 3, 2, 2, 17.00, 1),
(87, 14, 5, 2, 2, 16.50, 1),
(88, 15, 1, 2, 2, 14.00, 1),
(89, 15, 3, 2, 2, 15.50, 1),
(90, 15, 5, 2, 2, 14.00, 1),
(91, 16, 1, 1, 1, 12.50, 1),
(92, 16, 3, 1, 1, 11.00, 1),
(93, 16, 5, 1, 1, 14.50, 1),
(94, 17, 1, 1, 1, 18.00, 1),
(95, 17, 3, 1, 1, 17.50, 1),
(96, 17, 5, 1, 1, 19.00, 1),
(97, 18, 1, 1, 1, 9.50, 1),
(98, 18, 3, 1, 1, 10.00, 1),
(99, 18, 5, 1, 1, 11.50, 1),
(100, 19, 1, 1, 1, 15.50, 1),
(101, 19, 3, 1, 1, 16.00, 1),
(102, 19, 5, 1, 1, 15.00, 1),
(103, 20, 1, 1, 1, 14.00, 1),
(104, 20, 3, 1, 1, 14.50, 1),
(105, 20, 5, 1, 1, 13.50, 1),
(106, 21, 1, 1, 1, 16.50, 1),
(107, 21, 3, 1, 1, 15.00, 1),
(108, 21, 5, 1, 1, 17.50, 1),
(109, 22, 1, 1, 1, 13.50, 1),
(110, 22, 3, 1, 1, 12.00, 1),
(111, 22, 5, 1, 1, 14.50, 1),
(112, 23, 1, 1, 1, 11.00, 1),
(113, 23, 3, 1, 1, 10.50, 1),
(114, 23, 5, 1, 1, 12.00, 1),
(115, 24, 1, 1, 1, 19.00, 1),
(116, 24, 3, 1, 1, 18.50, 1),
(117, 24, 5, 1, 1, 20.00, 1),
(118, 25, 1, 1, 1, 14.50, 1),
(119, 25, 3, 1, 1, 15.00, 1),
(120, 25, 5, 1, 1, 13.50, 1),
(121, 26, 1, 1, 1, 17.50, 1),
(122, 26, 3, 1, 1, 18.00, 1),
(123, 26, 5, 1, 1, 16.50, 1),
(124, 27, 1, 1, 1, 10.00, 1),
(125, 27, 3, 1, 1, 9.50, 1),
(126, 27, 5, 1, 1, 11.00, 1),
(127, 28, 1, 1, 1, 15.00, 1),
(128, 28, 3, 1, 1, 14.50, 1),
(129, 28, 5, 1, 1, 16.00, 1),
(130, 29, 1, 1, 1, 12.50, 1),
(131, 29, 3, 1, 1, 13.00, 1),
(132, 29, 5, 1, 1, 11.50, 1),
(133, 30, 1, 1, 1, 18.50, 1),
(134, 30, 3, 1, 1, 19.00, 1),
(135, 30, 5, 1, 1, 17.50, 1),
(136, 16, 1, 2, 2, 13.00, 1),
(137, 16, 3, 2, 2, 12.00, 1),
(138, 16, 5, 2, 2, 15.00, 1),
(139, 17, 1, 2, 2, 18.50, 1),
(140, 17, 3, 2, 2, 18.00, 1),
(141, 17, 5, 2, 2, 19.50, 1),
(142, 18, 1, 2, 2, 10.50, 1),
(143, 18, 3, 2, 2, 11.00, 1),
(144, 18, 5, 2, 2, 12.00, 1),
(145, 19, 1, 2, 2, 16.00, 1),
(146, 19, 3, 2, 2, 16.50, 1),
(147, 19, 5, 2, 2, 15.50, 1),
(148, 20, 1, 2, 2, 14.50, 1),
(149, 20, 3, 2, 2, 15.00, 1),
(150, 20, 5, 2, 2, 14.00, 1),
(151, 21, 1, 2, 2, 17.00, 1),
(152, 21, 3, 2, 2, 15.50, 1),
(153, 21, 5, 2, 2, 18.00, 1),
(154, 22, 1, 2, 2, 14.00, 1),
(155, 22, 3, 2, 2, 12.50, 1),
(156, 22, 5, 2, 2, 15.00, 1),
(157, 23, 1, 2, 2, 11.50, 1),
(158, 23, 3, 2, 2, 11.00, 1),
(159, 23, 5, 2, 2, 12.50, 1),
(160, 24, 1, 2, 2, 19.50, 1),
(161, 24, 3, 2, 2, 19.00, 1),
(162, 24, 5, 2, 2, 20.00, 1),
(163, 25, 1, 2, 2, 15.00, 1),
(164, 25, 3, 2, 2, 15.50, 1),
(165, 25, 5, 2, 2, 14.00, 1),
(166, 26, 1, 2, 2, 18.00, 1),
(167, 26, 3, 2, 2, 18.50, 1),
(168, 26, 5, 2, 2, 17.00, 1),
(169, 27, 1, 2, 2, 10.50, 1),
(170, 27, 3, 2, 2, 10.00, 1),
(171, 27, 5, 2, 2, 11.50, 1),
(172, 28, 1, 2, 2, 15.50, 1),
(173, 28, 3, 2, 2, 15.00, 1),
(174, 28, 5, 2, 2, 16.50, 1),
(175, 29, 1, 2, 2, 13.00, 1),
(176, 29, 3, 2, 2, 13.50, 1),
(177, 29, 5, 2, 2, 12.00, 1),
(178, 30, 1, 2, 2, 19.00, 1),
(179, 30, 3, 2, 2, 19.50, 1),
(180, 30, 5, 2, 2, 18.00, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `invoices`
--

CREATE TABLE `invoices` (
  `id` int(11) NOT NULL,
  `invoice_number` varchar(50) NOT NULL,
  `issue_date` date NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'ISSUED',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `invoices`
--

INSERT INTO `invoices` (`id`, `invoice_number`, `issue_date`, `status`, `created_at`) VALUES
(1, 'F001-0001', '2026-02-23', 'ANULADO', '2026-02-24 15:26:22'),
(2, 'F001-0002', '2026-02-22', 'EMITIDO', '2026-02-24 15:26:22'),
(3, 'F001-0003', '2026-02-19', 'EMITIDO', '2026-02-24 15:26:22'),
(4, 'F001-0004', '2026-02-16', 'NC_APLICADA', '2026-02-24 15:26:22'),
(5, 'F001-0005', '2026-02-14', 'EMITIDO', '2026-02-24 15:26:22'),
(6, 'F001-0006', '2026-02-09', 'NC_APLICADA', '2026-02-24 15:26:22'),
(7, 'F001-0007', '2026-02-04', 'ANULADO', '2026-02-24 15:26:22'),
(8, 'F001-0008', '2026-02-21', 'EMITIDO', '2026-02-24 15:26:22'),
(9, 'F001-0009', '2026-02-20', 'EMITIDO', '2026-02-24 15:26:22'),
(10, 'F001-0010', '2026-02-12', 'EMITIDO', '2026-02-24 15:26:22'),
(11, 'F001-0011', '2026-02-24', 'EMITIDO', '2026-02-24 15:26:22'),
(12, 'F001-0012', '2026-01-25', 'NC_APLICADA', '2026-02-24 15:26:22'),
(13, 'F001-0013', '2026-02-18', 'EMITIDO', '2026-02-24 15:26:22'),
(14, 'F001-0014', '2026-02-15', 'EMITIDO', '2026-02-24 15:26:22'),
(15, 'F001-0015', '2026-02-23', 'EMITIDO', '2026-02-24 15:26:22'),
(16, 'F001-0016', '2026-01-15', 'ANULADO', '2026-02-24 15:26:22'),
(17, 'F001-0017', '2026-02-22', 'EMITIDO', '2026-02-24 15:26:22'),
(18, 'F001-0018', '2026-02-13', 'EMITIDO', '2026-02-24 15:26:22'),
(19, 'F001-0019', '2026-02-19', 'EMITIDO', '2026-02-24 15:26:22'),
(20, 'F001-0020', '2026-02-19', 'EMITIDO', '2026-02-24 15:26:22');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pdf_cache`
--

CREATE TABLE `pdf_cache` (
  `id` int(11) NOT NULL,
  `section_id` int(11) NOT NULL,
  `exam_id` int(11) NOT NULL,
  `payload` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`payload`)),
  `is_valid` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `pdf_cache`
--

INSERT INTO `pdf_cache` (`id`, `section_id`, `exam_id`, `payload`, `is_valid`, `created_at`, `updated_at`) VALUES
(1, 1, 1, '[{\"student_id\":1,\"name\":\"Mateo García\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 14.50},{\"course\": \"Lenguaje\", \"grade\": 16.00},{\"course\": \"Física\", \"grade\": 12.00}]},{\"student_id\":2,\"name\":\"Valentina Flores\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 17.50},{\"course\": \"Álgebra\", \"grade\": 18.00},{\"course\": \"Lenguaje\", \"grade\": 19.00}]},{\"student_id\":3,\"name\":\"Santiago Quispe\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 10.50},{\"course\": \"Lenguaje\", \"grade\": 11.00},{\"course\": \"Física\", \"grade\": 9.50}]},{\"student_id\":4,\"name\":\"Camila Rojas\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 19.00},{\"course\": \"Álgebra\", \"grade\": 20.00},{\"course\": \"Lenguaje\", \"grade\": 18.50}]},{\"student_id\":5,\"name\":\"Sebastián Mamani\",\"grades_data\":[{\"course\": \"Lenguaje\", \"grade\": 13.50},{\"course\": \"Física\", \"grade\": 14.00},{\"course\": \"Álgebra\", \"grade\": 13.00}]},{\"student_id\":16,\"name\":\"Andrés Silva\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 12.50},{\"course\": \"Lenguaje\", \"grade\": 14.50},{\"course\": \"Física\", \"grade\": 11.00}]},{\"student_id\":17,\"name\":\"Lucía Castro\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 17.50},{\"course\": \"Álgebra\", \"grade\": 18.00},{\"course\": \"Lenguaje\", \"grade\": 19.00}]},{\"student_id\":18,\"name\":\"Martín Gómez\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 9.50},{\"course\": \"Lenguaje\", \"grade\": 11.50},{\"course\": \"Física\", \"grade\": 10.00}]},{\"student_id\":19,\"name\":\"Paula Rivas\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 15.50},{\"course\": \"Lenguaje\", \"grade\": 15.00},{\"course\": \"Física\", \"grade\": 16.00}]},{\"student_id\":20,\"name\":\"Kevin Sánchez\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 14.50},{\"course\": \"Álgebra\", \"grade\": 14.00},{\"course\": \"Lenguaje\", \"grade\": 13.50}]}]', 1, '2026-02-24 15:37:22', '2026-02-24 15:37:22'),
(2, 2, 2, '[{\"student_id\":6,\"name\":\"Luciana Silva\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 17.00},{\"course\": \"Lenguaje\", \"grade\": 18.00},{\"course\": \"Física\", \"grade\": 16.00}]},{\"student_id\":7,\"name\":\"Matías Chuquimia\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 12.50},{\"course\": \"Lenguaje\", \"grade\": 13.00},{\"course\": \"Física\", \"grade\": 11.00}]},{\"student_id\":8,\"name\":\"Mariana Vargas\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 19.00},{\"course\": \"Álgebra\", \"grade\": 20.00},{\"course\": \"Lenguaje\", \"grade\": 20.00}]},{\"student_id\":9,\"name\":\"Diego Castro\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 15.00},{\"course\": \"Lenguaje\", \"grade\": 13.50},{\"course\": \"Física\", \"grade\": 14.00}]},{\"student_id\":10,\"name\":\"Sofía Mendoza\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 17.00},{\"course\": \"Álgebra\", \"grade\": 18.00},{\"course\": \"Lenguaje\", \"grade\": 19.00}]},{\"student_id\":21,\"name\":\"Renato Cruz\",\"grades_data\":[{\"course\": \"Lenguaje\", \"grade\": 18.00},{\"course\": \"Física\", \"grade\": 15.50},{\"course\": \"Álgebra\", \"grade\": 17.00}]},{\"student_id\":22,\"name\":\"Fabiola Tapia\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 14.00},{\"course\": \"Lenguaje\", \"grade\": 15.00},{\"course\": \"Física\", \"grade\": 12.50}]},{\"student_id\":23,\"name\":\"Diego Medina\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 11.00},{\"course\": \"Álgebra\", \"grade\": 11.50},{\"course\": \"Lenguaje\", \"grade\": 12.50}]},{\"student_id\":24,\"name\":\"Andrea Pineda\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 19.50},{\"course\": \"Lenguaje\", \"grade\": 20.00},{\"course\": \"Física\", \"grade\": 19.00}]},{\"student_id\":25,\"name\":\"Hugo Lazo\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 15.00},{\"course\": \"Lenguaje\", \"grade\": 14.00},{\"course\": \"Física\", \"grade\": 15.50}]}]', 1, '2026-02-24 15:37:22', '2026-02-24 15:37:22'),
(3, 3, 1, '[{\"student_id\":11,\"name\":\"Joaquín Ramos\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 8.50},{\"course\": \"Lenguaje\", \"grade\": 9.50},{\"course\": \"Física\", \"grade\": 10.00}]},{\"student_id\":12,\"name\":\"Daniela Torres\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 19.00},{\"course\": \"Álgebra\", \"grade\": 18.50},{\"course\": \"Lenguaje\", \"grade\": 17.50}]},{\"student_id\":13,\"name\":\"Gabriel Condori\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 14.00},{\"course\": \"Álgebra\", \"grade\": 12.50},{\"course\": \"Lenguaje\", \"grade\": 15.00}]},{\"student_id\":14,\"name\":\"Valeria Paucar\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 15.00},{\"course\": \"Lenguaje\", \"grade\": 16.00},{\"course\": \"Física\", \"grade\": 16.50}]},{\"student_id\":15,\"name\":\"Rodrigo Espinoza\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 14.50},{\"course\": \"Álgebra\", \"grade\": 13.50},{\"course\": \"Lenguaje\", \"grade\": 13.00}]},{\"student_id\":26,\"name\":\"Carmen Ruiz\",\"grades_data\":[{\"course\": \"Lenguaje\", \"grade\": 16.50},{\"course\": \"Física\", \"grade\": 18.00},{\"course\": \"Álgebra\", \"grade\": 17.50}]},{\"student_id\":27,\"name\":\"Héctor Vega\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 10.00},{\"course\": \"Lenguaje\", \"grade\": 11.00},{\"course\": \"Física\", \"grade\": 9.50}]},{\"student_id\":28,\"name\":\"Mónica Ríos\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 14.50},{\"course\": \"Álgebra\", \"grade\": 15.00},{\"course\": \"Lenguaje\", \"grade\": 16.00}]},{\"student_id\":29,\"name\":\"Raúl Peña\",\"grades_data\":[{\"course\": \"Álgebra\", \"grade\": 12.50},{\"course\": \"Lenguaje\", \"grade\": 11.50},{\"course\": \"Física\", \"grade\": 13.00}]},{\"student_id\":30,\"name\":\"Teresa Soto\",\"grades_data\":[{\"course\": \"Física\", \"grade\": 19.00},{\"course\": \"Álgebra\", \"grade\": 18.50},{\"course\": \"Lenguaje\", \"grade\": 17.50}]}]', 1, '2026-02-24 15:37:22', '2026-02-24 15:37:22');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `sections`
--

CREATE TABLE `sections` (
  `id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `sections`
--

INSERT INTO `sections` (`id`, `name`) VALUES
(1, '1ro Secundaria - A'),
(2, '3ro Secundaria - B'),
(3, '5to Secundaria - C');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `students`
--

CREATE TABLE `students` (
  `id` int(11) NOT NULL,
  `name` varchar(150) NOT NULL,
  `section_id` int(11) NOT NULL,
  `classroom_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `students`
--

INSERT INTO `students` (`id`, `name`, `section_id`, `classroom_id`) VALUES
(1, 'Mateo García', 1, 1),
(2, 'Valentina Flores', 1, 1),
(3, 'Santiago Quispe', 1, 1),
(4, 'Camila Rojas', 1, 1),
(5, 'Sebastián Mamani', 1, 1),
(6, 'Luciana Silva', 2, 2),
(7, 'Matías Chuquimia', 2, 2),
(8, 'Mariana Vargas', 2, 2),
(9, 'Diego Castro', 2, 2),
(10, 'Sofía Mendoza', 2, 2),
(11, 'Joaquín Ramos', 3, 3),
(12, 'Daniela Torres', 3, 3),
(13, 'Gabriel Condori', 3, 3),
(14, 'Valeria Paucar', 3, 3),
(15, 'Rodrigo Espinoza', 3, 3),
(16, 'Andrés Silva', 1, 1),
(17, 'Lucía Castro', 1, 1),
(18, 'Martín Gómez', 1, 1),
(19, 'Paula Rivas', 1, 1),
(20, 'Kevin Sánchez', 1, 1),
(21, 'Renato Cruz', 2, 2),
(22, 'Fabiola Tapia', 2, 2),
(23, 'Diego Medina', 2, 2),
(24, 'Andrea Pineda', 2, 2),
(25, 'Hugo Lazo', 2, 2),
(26, 'Carmen Ruiz', 3, 3),
(27, 'Héctor Vega', 3, 3),
(28, 'Mónica Ríos', 3, 3),
(29, 'Raúl Peña', 3, 3),
(30, 'Teresa Soto', 3, 3);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `student_annual_grades`
--

CREATE TABLE `student_annual_grades` (
  `id` int(11) NOT NULL,
  `student_id` int(11) NOT NULL,
  `classroom_id` int(11) NOT NULL,
  `annual_average` decimal(5,2) NOT NULL,
  `year` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `student_annual_grades`
--

INSERT INTO `student_annual_grades` (`id`, `student_id`, `classroom_id`, `annual_average`, `year`) VALUES
(1, 1, 1, 14.60, 2026),
(2, 2, 1, 18.40, 2026),
(3, 3, 1, 10.80, 2026),
(4, 4, 1, 19.20, 2026),
(5, 5, 1, 14.00, 2026),
(6, 6, 2, 16.50, 2026),
(7, 7, 2, 11.70, 2026),
(8, 8, 2, 19.40, 2026),
(9, 9, 2, 13.60, 2026),
(10, 10, 2, 17.50, 2026),
(11, 11, 3, 10.00, 2026),
(12, 12, 3, 18.50, 2026),
(13, 13, 3, 14.30, 2026),
(14, 14, 3, 16.10, 2026),
(15, 15, 3, 14.00, 2026),
(16, 16, 1, 13.00, 2026),
(17, 17, 1, 18.40, 2026),
(18, 18, 1, 10.70, 2026),
(19, 19, 1, 15.70, 2026),
(20, 20, 1, 14.20, 2026),
(21, 21, 2, 16.60, 2026),
(22, 22, 2, 13.60, 2026),
(23, 23, 2, 11.40, 2026),
(24, 24, 2, 19.30, 2026),
(25, 25, 2, 14.60, 2026),
(26, 26, 3, 17.60, 2026),
(27, 27, 3, 10.40, 2026),
(28, 28, 3, 15.40, 2026),
(29, 29, 3, 12.60, 2026),
(30, 30, 3, 18.60, 2026);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `view_document_status`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `view_document_status` (
`document_id` int(11)
,`invoice_number` varchar(50)
,`issue_date` date
,`status` varchar(20)
,`days_elapsed` int(7)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `view_libreta_dataset`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `view_libreta_dataset` (
`section_id` int(11)
,`exam_id` int(11)
,`student_id` int(11)
,`name` varchar(150)
,`grades_data` mediumtext
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `view_unidad_promedio`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `view_unidad_promedio` (
`student_id` int(11)
,`area_id` int(11)
,`unit_id` int(11)
,`unit_average` decimal(4,0)
);

-- --------------------------------------------------------

--
-- Estructura para la vista `view_document_status`
--
DROP TABLE IF EXISTS `view_document_status`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_document_status`  AS SELECT `invoices`.`id` AS `document_id`, `invoices`.`invoice_number` AS `invoice_number`, `invoices`.`issue_date` AS `issue_date`, `invoices`.`status` AS `status`, to_days(curdate()) - to_days(`invoices`.`issue_date`) AS `days_elapsed` FROM `invoices` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `view_libreta_dataset`
--
DROP TABLE IF EXISTS `view_libreta_dataset`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_libreta_dataset`  AS SELECT `s`.`id` AS `section_id`, `g`.`exam_id` AS `exam_id`, `st`.`id` AS `student_id`, `st`.`name` AS `name`, concat('[',group_concat(json_object('course',`c`.`name`,'grade',`g`.`grade`) separator ','),']') AS `grades_data` FROM (((`students` `st` join `grades` `g` on(`st`.`id` = `g`.`student_id`)) join `courses` `c` on(`g`.`course_id` = `c`.`id`)) join `sections` `s` on(`st`.`section_id` = `s`.`id`)) GROUP BY `s`.`id`, `g`.`exam_id`, `st`.`id`, `st`.`name` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `view_unidad_promedio`
--
DROP TABLE IF EXISTS `view_unidad_promedio`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_unidad_promedio`  AS SELECT `g`.`student_id` AS `student_id`, `c`.`area_id` AS `area_id`, `g`.`unit_id` AS `unit_id`, round(avg(`g`.`grade`),0) AS `unit_average` FROM (`grades` `g` join `courses` `c` on(`g`.`course_id` = `c`.`id`)) WHERE `g`.`is_active` = 1 GROUP BY `g`.`student_id`, `c`.`area_id`, `g`.`unit_id` ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `areas`
--
ALTER TABLE `areas`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `classrooms`
--
ALTER TABLE `classrooms`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `courses`
--
ALTER TABLE `courses`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_courses_area` (`area_id`);

--
-- Indices de la tabla `credit_notes`
--
ALTER TABLE `credit_notes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_credit_notes_invoice` (`parent_invoice_id`);

--
-- Indices de la tabla `fe_audit_log`
--
ALTER TABLE `fe_audit_log`
  ADD PRIMARY KEY (`audit_id`);

--
-- Indices de la tabla `grades`
--
ALTER TABLE `grades`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_grades_student` (`student_id`),
  ADD KEY `fk_grades_course` (`course_id`);

--
-- Indices de la tabla `invoices`
--
ALTER TABLE `invoices`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `pdf_cache`
--
ALTER TABLE `pdf_cache`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_section_exam` (`section_id`,`exam_id`);

--
-- Indices de la tabla `sections`
--
ALTER TABLE `sections`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `students`
--
ALTER TABLE `students`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_students_section` (`section_id`),
  ADD KEY `fk_students_classroom` (`classroom_id`);

--
-- Indices de la tabla `student_annual_grades`
--
ALTER TABLE `student_annual_grades`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_annual_student` (`student_id`),
  ADD KEY `fk_annual_classroom` (`classroom_id`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `areas`
--
ALTER TABLE `areas`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `classrooms`
--
ALTER TABLE `classrooms`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `courses`
--
ALTER TABLE `courses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `credit_notes`
--
ALTER TABLE `credit_notes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `fe_audit_log`
--
ALTER TABLE `fe_audit_log`
  MODIFY `audit_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `grades`
--
ALTER TABLE `grades`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `invoices`
--
ALTER TABLE `invoices`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT de la tabla `pdf_cache`
--
ALTER TABLE `pdf_cache`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `sections`
--
ALTER TABLE `sections`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `students`
--
ALTER TABLE `students`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT de la tabla `student_annual_grades`
--
ALTER TABLE `student_annual_grades`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `courses`
--
ALTER TABLE `courses`
  ADD CONSTRAINT `fk_courses_area` FOREIGN KEY (`area_id`) REFERENCES `areas` (`id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `credit_notes`
--
ALTER TABLE `credit_notes`
  ADD CONSTRAINT `fk_credit_notes_invoice` FOREIGN KEY (`parent_invoice_id`) REFERENCES `invoices` (`id`);

--
-- Filtros para la tabla `grades`
--
ALTER TABLE `grades`
  ADD CONSTRAINT `fk_grades_course` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_grades_student` FOREIGN KEY (`student_id`) REFERENCES `students` (`id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `pdf_cache`
--
ALTER TABLE `pdf_cache`
  ADD CONSTRAINT `fk_pdf_cache_section` FOREIGN KEY (`section_id`) REFERENCES `sections` (`id`);

--
-- Filtros para la tabla `students`
--
ALTER TABLE `students`
  ADD CONSTRAINT `fk_students_classroom` FOREIGN KEY (`classroom_id`) REFERENCES `classrooms` (`id`),
  ADD CONSTRAINT `fk_students_section` FOREIGN KEY (`section_id`) REFERENCES `sections` (`id`);

--
-- Filtros para la tabla `student_annual_grades`
--
ALTER TABLE `student_annual_grades`
  ADD CONSTRAINT `fk_annual_classroom` FOREIGN KEY (`classroom_id`) REFERENCES `classrooms` (`id`),
  ADD CONSTRAINT `fk_annual_student` FOREIGN KEY (`student_id`) REFERENCES `students` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
