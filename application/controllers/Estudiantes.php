<?php
class Estudiantes extends CI_Controller {

    public function __construct() {
        parent::__construct();
        $this->load->model(array('sp_model'));
    }

    public function reporte($student_id) {
        $data['notas'] = $this->sp_model->ejecutar_notas_anuales_sp($student_id);
        
        $data['alumno'] = $this->db->get_where('students', ['id' => $student_id])->row();
        
        $this->load->view('reporte_notas_view', $data);
    }
}