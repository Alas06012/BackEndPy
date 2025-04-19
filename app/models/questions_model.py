from app import mysql

class Questions:
    @staticmethod
    def get_active_users():
        cur = mysql.connection.cursor()
        cur.execute("""SELECT pk_user, user_name, user_lastname, user_email, user_role, status FROM users WHERE status = 'ACTIVE' """)
        users = cur.fetchall()
        return users