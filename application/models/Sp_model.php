<?php
class Sp_model extends CI_Model {

    public function __construct() {
        parent::__construct();
        $this->load->database();
    }

    public function ejecutar_libreta_sp($section_id, $exam_id) {
        $sql = "CALL sp_generate_libreta_dataset(?, ?)";
        $query = $this->db->query($sql, array($section_id, $exam_id));
        
        $res = $query->row(); 
        if ($this->db->conn_id instanceof mysqli) {
            $this->db->conn_id->next_result();
        }
        return ($res) ? json_decode($res->dataset_json) : [];
    }

     public function ejecutar_notas_anuales_sp($student_id) {
        $sql = "CALL sp_get_area_unit_and_annual_grades(?)";
        $query = $this->db->query($sql, array($student_id));
        
        $res = $query->result();
        if ($this->db->conn_id instanceof mysqli) {
            $this->db->conn_id->next_result();
        }
        
        return $res;
    }

    public function procesar_anulacion_sp($doc_id, $user_id) {
        $sql = "CALL sp_process_void_request(?, ?)";
        return $this->db->query($sql, array($doc_id, $user_id));
    }
}