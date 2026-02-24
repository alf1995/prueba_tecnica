<?php
class Academia_model extends CI_Model {

    public function get_estudiantes_detallado() {
        $this->db->select('st.id, st.name as estudiante, s.name as seccion, c.name as aula');
        $this->db->from('students st');
        $this->db->join('sections s', 'st.section_id = s.id');
        $this->db->join('classrooms c', 'st.classroom_id = c.id');
        $this->db->order_by('s.name', 'ASC'); // Ordenado por sección
        
        return $this->db->get()->result();
    }

    public function get_status_facturas() {
        return $this->db->get('view_document_status')->result();
    }

    public function get_libretas() {
        return $this->db->get('view_libreta_dataset')->result();
    }

    public function get_promedios_unidades() {
        return $this->db->get('view_unidad_promedio')->result();
    }
}