from app import mysql
import MySQLdb

class LevelModel:

    @staticmethod
    def create_level(name, description):
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                INSERT INTO mcer_level (level_name, level_desc)
                VALUES (%s, %s)
            """, (name, description))
            mysql.connection.commit()
            return True
        except Exception as e:
            return str(e).lower()

    @staticmethod
    def edit_level(id_, **kwargs):
        try:
            if not kwargs:
                return "No fields to update."

            fields = []
            values = []

            for field, value in kwargs.items():
                fields.append(f"{field} = %s")
                values.append(value)

            values.append(id_)

            query = f"""
                UPDATE mcer_level
                SET {', '.join(fields)}
                WHERE pk_level = %s
            """

            cur = mysql.connection.cursor()
            cur.execute(query, values)
            mysql.connection.commit()
            return True
        except Exception as e:
            return str(e).lower()

    @staticmethod
    def delete_level(id_):
        try:
            cur = mysql.connection.cursor()
            cur.execute("DELETE FROM mcer_level WHERE pk_level = %s", (id_,))
            mysql.connection.commit()
            return True
        except Exception as e:
            return str(e).lower()

    @staticmethod
    def get_level_by_id(id_):
        cur = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cur.execute("SELECT * FROM mcer_level WHERE pk_level = %s", (id_,))
        return cur.fetchone()

    @staticmethod
    def get_all_levels():
        cur = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cur.execute("SELECT * FROM mcer_level ORDER BY pk_level ASC")
        return cur.fetchall()

    @staticmethod
    def get_paginated_levels(page=1, per_page=10, search=None):
        try:
            cur = mysql.connection.cursor(MySQLdb.cursors.DictCursor)

            params = []
            where_clause = ""
            if search:
                where_clause = "WHERE level_name LIKE %s OR level_desc LIKE %s"
                search_term = f"%{search}%"
                params.extend([search_term, search_term])

            count_query = f"SELECT COUNT(*) AS total FROM mcer_level {where_clause}"
            cur.execute(count_query, tuple(params))
            total = cur.fetchone()['total']

            offset = (page - 1) * per_page
            query = f"""
                SELECT * FROM mcer_level
                {where_clause}
                ORDER BY pk_level DESC
                LIMIT %s OFFSET %s
            """
            cur.execute(query, tuple(params + [per_page, offset]))
            data = cur.fetchall()

            return {
                'data': data,
                'total': total,
                'pages': max(1, (total + per_page - 1) // per_page)
            }
        except Exception as e:
            return str(e)
