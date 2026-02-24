<?php
class Academia extends CI_Controller {

    public function __construct() {
        parent::__construct();
        $this->load->model(array('academia_model'));
    }

    public function index() {
        $data['estudiantes_lista'] = $this->academia_model->get_estudiantes_detallado();        
        $this->load->view('lista_estudiantes', $data);
    }

    public function facturas(){
        $data['facturas'] = $this->academia_model->get_status_facturas();
        $this->load->view('reporte_factura', $data);
    }

    public function libretas(){
        $data['libretas'] = $this->academia_model->get_libretas();
        $this->load->view('reporte_libretas', $data);
    }

    public function promedios(){
        $data['promedios'] = $this->academia_model->get_promedios_unidades();
        $this->load->view('reporte_promedios', $data);
    }
}