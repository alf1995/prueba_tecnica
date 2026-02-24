--
-- Reporte histórico de promedios anuales de 2023 y 2024
--
SELECT * FROM (
    SELECT student_id, classroom_id, annual_average, '2023' as period FROM student_annual_grades
    UNION ALL
    SELECT student_id, classroom_id, annual_average, '2024' as period FROM student_annual_grades
) AS historico
WHERE student_id IN (SELECT id FROM students WHERE section_id = 1)
AND annual_average > (SELECT AVG(annual_average) FROM student_annual_grades);

--
-- Query Mejorado de reporte historico
-- Se elimina el UNION ALL
-- Usamos CROSS JOIN para precalcular los datos una vez y se reutilice
-- Se aplica filtro de por año  desde el inicio para reducir los datos a procesar
--

SELECT sag.student_id,
       sag.classroom_id,
       sag.annual_average,
       sag.year AS period
FROM student_annual_grades sag
JOIN students s 
    ON s.id = sag.student_id
CROSS JOIN (
    SELECT AVG(annual_average) AS global_avg
    FROM student_annual_grades
) avg_table
WHERE sag.year IN (2023, 2024)
AND s.section_id = 1
AND sag.annual_average > avg_table.global_avg;
