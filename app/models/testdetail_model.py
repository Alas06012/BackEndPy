from app import mysql

class TestDetail:
    @staticmethod
    def create_detail(test_fk, title_fk, question_fk):
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT INTO test_details (test_fk, title_fk, question_fk)
            VALUES (%s, %s, %s)
        """, (test_fk, title_fk, question_fk))