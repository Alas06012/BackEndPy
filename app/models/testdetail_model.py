from app import mysql

class TestDetail:
    @staticmethod
    def create_detail(test_fk, title_fk, question_fk):
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT INTO test_details (test_fk, title_fk, question_fk)
            VALUES (%s, %s, %s)
        """, (test_fk, title_fk, question_fk))
        
        
    @staticmethod
    def update_answer_in_testdetails(test_id, question_id, title_id, user_answer_id):
        """
        Actualiza la respuesta elegida por el usuario en test_details.
        """
        cur = mysql.connection.cursor()
        cur.execute("""
            UPDATE test_details
            SET answer_fk = %s
            WHERE test_fk = %s AND question_fk = %s AND title_fk = %s
        """, (user_answer_id, test_id, question_id, title_id))
        return cur.rowcount  # Opcional: puedes usar esto para verificar si se actualizó algo
    
    @staticmethod
    def get_all_detail():
        cur = mysql.connection.cursor()
        cur.execute("""SELECT t.pk_testdetail, t.test_fk, qt.title_test, t.title_fk, qt.title_type, qt.title_url, q.question_text, t.question_fk, ts.section_desc, ml.level_name, a.answer_text, t.answer_fk, CASE WHEN a.is_correct = 1 THEN 'Correcta' ELSE 'Incorrecta' END AS is_correct FROM test_details t INNER JOIN questions_titles qt ON t.title_fk = qt.pk_title INNER JOIN questions q ON t.question_fk = q.pk_question LEFT JOIN answers a -- Permite respuestas NULL ON t.answer_fk = a.pk_answer LEFT JOIN toeic_sections ts -- Permite secciones no asignadas ON q.toeic_section_fk = ts.section_pk LEFT JOIN mcer_level ml -- Permite niveles no asignados ON q.level_fk = ml.pk_level WHERE t.test_fk = 29;""")
        return cur.fetchall()