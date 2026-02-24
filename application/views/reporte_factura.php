<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Dashboard - Vistas SQL</title>

    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">

    <style>
        body {
            font-family: 'Inter', sans-serif;
            background: #f4f6f9;
            margin: 0;
            padding: 40px;
        }

        h1 {
            margin-bottom: 40px;
            font-weight: 700;
            color: #1e293b;
        }

        .card {
            background: #fff;
            padding: 25px;
            margin-bottom: 40px;
            border-radius: 12px;
            box-shadow: 0 8px 25px rgba(0,0,0,0.05);
            margin-top: 10px;
        }

        .card h2 {
            margin-top: 0;
            margin-bottom: 20px;
            font-size: 18px;
            color: #334155;
            border-left: 5px solid #3b82f6;
            padding-left: 10px;
        }

        .table-container {
            overflow-x: auto;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        thead {
            background: #f1f5f9;
        }

        th {
            padding: 12px;
            text-align: left;
            font-size: 13px;
            text-transform: uppercase;
            letter-spacing: .5px;
            color: #475569;
        }

        td {
            padding: 12px;
            border-bottom: 1px solid #e2e8f0;
            font-size: 14px;
            color: #334155;
        }

        tr:hover {
            background: #f8fafc;
        }

        .badge {
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }

        .badge-success {
            background: #dcfce7;
            color: #166534;
        }

        .badge-warning {
            background: #fef9c3;
            color: #854d0e;
        }

        .badge-danger {
            background: #fee2e2;
            color: #991b1b;
        }

        code {
            font-size: 11px;
            background: #f1f5f9;
            padding: 5px;
            border-radius: 6px;
            display: block;
            max-height: 80px;
            overflow: auto;
        }

        .highlight {
            font-weight: 700;
            color: #3b82f6;
        }
    </style>
</head>

<body>
<a href="<?= base_url() ?>" style="">Volver atras</a>
<div class="card">
    <h2>Estado de Documentos</h2>
    <div class="table-container">
        <table>
            <thead>
                <tr>
                    <th>Número</th>
                    <th>Fecha Emisión</th>
                    <th>Estado</th>
                    <th>Días Transcurridos</th>
                </tr>
            </thead>
            <tbody>
            <?php foreach($facturas as $f): ?>
                <tr>
                    <td><?= $f->invoice_number ?></td>
                    <td><?= $f->issue_date ?></td>
                    <td>
                        <?php 
                            $class = 'badge-success';
                            if($f->status == 'Pendiente') $class = 'badge-warning';
                            if($f->status == 'Anulado') $class = 'badge-danger';
                        ?>
                        <span class="badge <?= $class ?>">
                            <?= $f->status ?>
                        </span>
                    </td>
                    <td><?= $f->days_elapsed ?> días</td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
</body>
</html>