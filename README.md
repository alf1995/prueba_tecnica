# Cuestionario
<p align="center">
  <a href="https://github.com/alf1995/prueba_tecnica/blob/fd0e0305eef58edfa256a9c4f51f4b92c7c0ed08/files/Cuestionario.pdf" target="_blank">
    <strong>Respuestas del cuestionario </strong>
  </a>
</p>


## Mejoras Aplicada a Base de Datos

Este repositorio contiene la lógica de base de datos optimizada para el manejo de registros académicos y facturación. A continuación, se detallan las estrategias de optimización e integridad implementadas.

---

## - Estrategia de Caché
* **Procedimiento `sp_generate_libreta_dataset`**: Implementa un sistema de **Caché de Resultados**.
    * Antes de realizar joins pesados entre estudiantes, notas y cursos, el sistema verifica si existe un JSON generado, reduciendo la carga del CPU en reportes masivos.
    * **Optimización de Memoria**: Uso de `SET SESSION group_concat_max_len = 1000000;` para prevenir la corrupción de datos en cadenas extensas.
    * **Persistencia**: Utiliza `ON DUPLICATE KEY UPDATE` para mantener la integridad y evitar registros duplicados.

## - Normalización de Datos
* **Procedimiento `sp_normalize_invoice_data`**: Utiliza una subconsulta anidada para mitigar la restricción de MariaDB que impide leer y borrar de la misma tabla simultáneamente.
* **Función `fn_promedio_ponderado`**: Implementa validación de rango para asegurar que el promedio de nota se mantenga estrictamente entre **0 y 20**.

## - Integridad Referencial
* **Constraints**: Uso de `FOREIGN KEY` en tablas clave como `courses` y `grades` para garantizar la consistencia ante eliminaciones y evitar datos huérfanos.
* **Precisión Numérica**: Implementación de `DECIMAL(5,2)` para el almacenamiento de calificaciones, evitando los errores de redondeo inherentes al tipo de dato `FLOAT`.

## - Optimizaciones en Vistas
* **Vista `view_document_status`**: Cálculo dinámico de `days_elapsed` mediante `to_days(curdate())`, simplificando la lógica en los procedimientos de facturación.
* **Vista `view_unidad_promedio`**: Implementa un filtro para registros donde `is_active = 1`, facilitando la **eliminación lógica** y el mantenimiento de históricos sin afectar los cálculos de promedios actuales.

## Proyecto
<p align="center">
  <img src="https://raw.githubusercontent.com/alf1995/prueba_tecnica/main/files/dashboard.png" width="600" title="Imagen de Proyecto">
</p>
