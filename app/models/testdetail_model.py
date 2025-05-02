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