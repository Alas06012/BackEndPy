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

        #Actualiza la respuesta elegida por el usuario en test_details.
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
                -- qt.title_url,
                q.question_text,
                ts.section_desc AS section,
                -- ml.level_name AS level,
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
    

    
    @staticmethod
    def get_by_test_id(test_id):
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                ts.type_ as section_type,
                ts.section_desc,
                qt.pk_title as title_id,
                qt.title_name,
                qt.title_test,
                qt.title_type,
                qt.title_url,
                q.pk_question as question_id,
                q.question_text,
                a.pk_answer as answer_id,
                a.answer_text,
                a.is_correct,
                td.answer_fk as selected_answer_id
            FROM tests as t
            INNER JOIN test_details as td ON t.pk_test = td.test_fk
            INNER JOIN questions_titles as qt ON td.title_fk = qt.pk_title
            INNER JOIN questions as q ON td.question_fk = q.pk_question
            INNER JOIN answers as a ON a.question_fk = q.pk_question
            INNER JOIN toeic_sections as ts ON ts.section_pk = q.toeic_section_fk
            WHERE t.pk_test = %s
            ORDER BY ts.type_, qt.pk_title, q.pk_question, a.pk_answer
        """, (test_id,))
        return cur.fetchall()
