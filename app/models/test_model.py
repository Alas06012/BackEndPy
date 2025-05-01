from app import mysql

class Test:
    @staticmethod
    def get_all_test():
        cur = mysql.connection.cursor()
        cur.execute("""SELECT * FROM test """)
        test = cur.fetchall()
        return test
    
    @staticmethod
    def get_test_by_id(test_id):
        cur = mysql.connection.cursor()
        cur.execute("""SELECT * FROM test WHERE pk_test = %s""", (test_id,))
        test = cur.fetchone()
        return test
    
    @staticmethod
    def create_test(user_fk):
        cur = mysql.connection.cursor()
        cur.execute("""INSERT INTO tests (user_fk) VALUES (%s)""", (user_fk,))
        test_id = cur.lastrowid
        return test_id

    @staticmethod
    def get_random_titles():
        cur = mysql.connection.cursor()
        cur.execute("""
            (
            SELECT pk_title FROM questions_titles
            WHERE title_type = 'READING' AND status = 'ACTIVE'
            ORDER BY RAND() LIMIT 25
            )
            UNION ALL
            (
            SELECT pk_title FROM questions_titles
            WHERE title_type = 'LISTENING' AND status = 'ACTIVE'
            ORDER BY RAND() LIMIT 25
            )
        """)
        return cur.fetchall()