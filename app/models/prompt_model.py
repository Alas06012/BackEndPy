from app import mysql

class Prompt:
    
    @staticmethod
    def create_prompt(name, prompt_content):
        try:
            cur = mysql.connection.cursor()

            # Inicia la transacción
            mysql.connection.begin()

            # 1. Inactivar todos los prompts activos
            cur.execute("""
                        UPDATE prompts 
                        SET status = 'INACTIVE' 
                        WHERE status = 'ACTIVE'
                        """)

            # 2. Insertar el nuevo prompt como activo
            cur.execute("""
                INSERT INTO prompts (prompt_name, prompt_value, status) 
                VALUES (%s, %s, %s)
            """, (name, prompt_content, "ACTIVE"))

            # Confirmar cambios
            mysql.connection.commit()

            return 'True'
        except Exception as e:
            # Si hay un error, hacer rollback para deshacer todo
            mysql.connection.rollback()
            return str(e).lower()


    @staticmethod
    def activate_prompt(id_):
        try:
            cur = mysql.connection.cursor()

            # Inicia la transacción
            mysql.connection.begin()
            
            cur.execute("""
                    UPDATE prompts 
                    SET status = 'INACTIVE' 
                    WHERE status = 'ACTIVE'
                    """)

            # 2. Insertar el nuevo prompt como activo
            cur.execute("""
                UPDATE prompts 
                SET status = 'ACTIVE'
                WHERE pk_prompt = %s
                """, (id_,))

            # Confirmar cambios
            mysql.connection.commit()

            return 'True'
        except Exception as e:
            # Si hay un error, hacer rollback para deshacer todo
            mysql.connection.rollback()
            return str(e).lower()


       
    @staticmethod
    def get_paginated_prompts(filters=None, page=1, per_page=20):
        try:
            conn = mysql.connection
            cur = conn.cursor()

            where_clauses = ["1=1"]
            params = []

            if filters:
                if filters.get("status"):
                    where_clauses.append("status = %s")
                    params.append(filters["status"])
                
                if filters.get("prompt_value"):
                    where_clauses.append("prompt_value LIKE %s")
                    params.append(f"%{filters['prompt_value']}%")
                    
                if filters.get("prompt_name"):
                    where_clauses.append("prompt_name LIKE %s")
                    params.append(f"%{filters['prompt_name']}%")

            where_clause = " AND ".join(where_clauses)

            # Count total
            count_query = f"SELECT COUNT(*) FROM prompts WHERE {where_clause}"
            cur.execute(count_query, params)
            total = list(cur.fetchone().values())[0]

            # Data with pagination
            offset = (page - 1) * per_page
            data_query = f"""
                SELECT
                    pk_prompt,
                    prompt_name,
                    prompt_value,
                    status,
                    created_at,
                    updated_at
                FROM prompts
                WHERE {where_clause}
                ORDER BY updated_at DESC
                LIMIT %s OFFSET %s
            """
            cur.execute(data_query, params + [per_page, offset])
            data = cur.fetchall()

            return {
                'data': data,
                'total': total,
                'pages': max(1, (total + per_page - 1) // per_page)
            }

        except Exception as e:
            print(f"Error en get_paginated_prompts: {str(e)}")
            return str(e)
        
        
    @staticmethod
    def get_active_prompt():
        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                SELECT prompt_value 
                FROM prompts 
                WHERE status = 'ACTIVE'
                LIMIT 1
            """)
            result = cur.fetchall()
            return result if result else None
        except Exception as e:
            print(f"Error al obtener prompt: {str(e)}")
            return None
        
    
