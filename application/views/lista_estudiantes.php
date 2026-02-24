<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Listado de Estudiantes</title>

    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">

    <style>
        body {
            font-family: 'Inter', sans-serif;
            background: #f4f6f9;
            margin: 0;
            padding: 40px;
        }

        .card {
            background: #ffffff;
            padding: 30px;
            border-radius: 14px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.05);
            max-width: 1100px;
            margin: auto;
        }

        h2 {
            margin-top: 0;
            margin-bottom: 25px;
            font-size: 20px;
            font-weight: 700;
            color: #1e293b;
            border-left: 6px solid #2ecc71;
            padding-left: 12px;
        }

        /* BOTONES SUPERIORES */

        .report-buttons {
            display: flex;
            gap: 15px;
            margin-bottom: 30px;
            flex-wrap: wrap;
        }

        .report-btn {
            flex: 1;
            min-width: 200px;
            text-decoration: none;
            padding: 14px 20px;
            border-radius: 10px;
            font-weight: 600;
            text-align: center;
            transition: all 0.2s ease-in-out;
            color: white;
        }

        .btn-1 { background: #3b82f6; }
        .btn-2 { background: #8b5cf6; }
        .btn-3 { background: #f59e0b; }

        .report-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(0,0,0,0.1);
            opacity: 0.95;
        }

        /* TABLA */

        .table-container {
            overflow-x: auto;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        thead {
            background: linear-gradient(90deg, #27ae60, #2ecc71);
            color: white;
        }

        th {
            padding: 14px;
            text-align: left;
            font-size: 13px;
            text-transform: uppercase;
            letter-spacing: .5px;
        }

        td {
            padding: 14px;
            border-bottom: 1px solid #e5e7eb;
            font-size: 14px;
            color: #334155;
        }

        tbody tr:hover {
            background-color: #f9fafb;
        }

        .student-name {
            font-weight: 600;
            color: #111827;
        }

        .aula-badge {
            background: #dcfce7;
            color: #166534;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }

        .empty-state {
            text-align: center;
            padding: 30px;
            color: #64748b;
            font-style: italic;
        }

        .id-column {
            color: #94a3b8;
            font-weight: 600;
        }
    </style>
</head>

<body>

<div class="card">

    <!-- BOTONES SUPERIORES -->
    <div class="report-buttons">
        <a href="<?= base_url('reportes/documentos') ?>" class="report-btn btn-1">
            Reporte de Documentos
        </a>

        <a href="<?= base_url('reportes/libretas') ?>" class="report-btn btn-2">
            Reporte de Libretas
        </a>

        <a href="<?= base_url('reportes/promedios') ?>" class="report-btn btn-3">
            Reporte de Promedios
        </a>
    </div>

    <h2>Listado de Estudiantes por Sección y Aula</h2>

    <div class="table-container">
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Nombre del Estudiante</th>
                    <th>Sección / Clase</th>
                    <th>Aula Asignada</th>
                </tr>
            </thead>
            <tbody>
                <?php if(!empty($estudiantes_lista)): ?>
                    <?php foreach($estudiantes_lista as $e): ?>
                        <tr>
                            <td class="id-column"><?= $e->id ?></td>
                            <td class="student-name"><?= $e->estudiante ?></td>
                            <td><?= $e->seccion ?></td>
                            <td>
                                <span class="aula-badge">
                                    <?= $e->aula ?>
                                </span>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php else: ?>
                    <tr>
                        <td colspan="4" class="empty-state">
                            ⚠ No hay estudiantes registrados.
                        </td>
                    </tr>
                <?php endif; ?>
            </tbody>
        </table>
    </div>

</div>

</body>
</html>