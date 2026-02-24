<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Notas del Alumno</title>

    <style>
        body {
            font-family: Arial, Helvetica, sans-serif;
            background-color: #f4f6f9;
            margin: 40px;
        }

        .card {
            background: #ffffff;
            border-radius: 10px;
            padding: 25px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.08);
            margin-top: 10px;
        }

        h2 {
            margin-bottom: 20px;
            color: #2c3e50;
        }

        .student-name {
            color: #3498db;
            font-weight: bold;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }

        thead {
            background: linear-gradient(90deg, #2ecc71, #27ae60);
            color: white;
        }

        th, td {
            padding: 12px;
            text-align: center;
            border-bottom: 1px solid #ddd;
        }

        tbody tr:hover {
            background-color: #f2f9ff;
        }

        .annual-grade {
            font-weight: bold;
            border-radius: 6px;
            padding: 6px 10px;
        }

        .grade-high {
            background-color: #d4edda;
            color: #155724;
        }

        .grade-medium {
            background-color: #fff3cd;
            color: #856404;
        }

        .grade-low {
            background-color: #f8d7da;
            color: #721c24;
        }

        .footer-note {
            margin-top: 15px;
            font-size: 13px;
            color: #666;
        }

        @media (max-width: 768px) {
            table {
                font-size: 13px;
            }
        }
    </style>
</head>
<body>
<a href="<?= base_url() ?>" style="">Volver atras</a>
<div class="card">

    <h2> Notas de: <span class="student-name"><?= $alumno->name ?></span></h2>

    <table>
        <thead>
            <tr>
                <th>Área</th>
                <th>Unidad 1</th>
                <th>Unidad 2</th>
                <th>Unidad 3</th>
                <th>Unidad 4</th>
                <th>Promedio Anual</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach($notas as $n): 
                
                $gradeClass = 'grade-low';
                if($n->annual_grade >= 17) {
                    $gradeClass = 'grade-high';
                } elseif($n->annual_grade >= 13) {
                    $gradeClass = 'grade-medium';
                }
            ?>
            <tr>
                <td><strong>Área <?= $n->area_id ?></strong></td>
                <td><?= $n->unit_1 ?? '-' ?></td>
                <td><?= $n->unit_2 ?? '-' ?></td>
                <td><?= $n->unit_3 ?? '-' ?></td>
                <td><?= $n->unit_4 ?? '-' ?></td>
                <td>
                    <span class="annual-grade <?= $gradeClass ?>">
                        <?= number_format($n->annual_grade, 2) ?>
                    </span>
                </td>
            </tr>
            <?php endforeach; ?>
        </tbody>
    </table>


</div>

</body>
</html>