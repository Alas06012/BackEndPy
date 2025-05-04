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
    def get_all_detail(test_fk):
        if not test_fk:
            return None  # Mejor devolver None para manejar el error en el controller
        
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                qt.title_test AS title,
                qt.title_type,
                qt.title_url,
                q.question_text,
                ts.section_desc AS section,
                ml.level_name AS level,
                a.answer_text AS student_answer,
                a.is_correct
            FROM test_details t 
            INNER JOIN questions_titles qt ON t.title_fk = qt.pk_title 
            INNER JOIN questions q ON t.question_fk = q.pk_question 
            LEFT JOIN answers a ON t.answer_fk = a.pk_answer 
            LEFT JOIN toeic_sections ts ON q.toeic_section_fk = ts.section_pk 
            LEFT JOIN mcer_level ml ON q.level_fk = ml.pk_level 
            WHERE t.test_fk = %s
        """, (test_fk,))
        
        # Obtener datos y descripción de columnas
        data = cur.fetchall()
        columns = [desc[0] for desc in cur.description] if cur.description else []
        return {'data': data, 'columns': columns}