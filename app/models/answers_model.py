from app import mysql

class Answers:
    @staticmethod
    def create_answer(fk_question, answer_text, is_correct):
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT INTO answers (question_fk, answer_text, is_correct)
            VALUES (%s, %s, %s)
        """, (fk_question, answer_text, is_correct))
        mysql.connection.commit()