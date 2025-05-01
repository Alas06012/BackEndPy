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
                SELECT * 
                FROM questions_titles qt
                WHERE qt.title_type = 'READING'
                    AND qt.status = 'ACTIVE'
                    AND EXISTS (
                    SELECT 1 
                    FROM questions q 
                    WHERE q.title_fk = qt.pk_title 
                        AND q.status = 'ACTIVE'
                    )
                ORDER BY RAND()
                LIMIT 1
                )
                UNION ALL
                (
                SELECT * 
                FROM questions_titles qt
                WHERE qt.title_type = 'LISTENING'
                    AND qt.status = 'ACTIVE'
                    AND EXISTS (
                    SELECT 1 
                    FROM questions q 
                    WHERE q.title_fk = qt.pk_title 
                        AND q.status = 'ACTIVE'
                    )
                ORDER BY RAND()
                LIMIT 1
                )
        """)
        return cur.fetchall()