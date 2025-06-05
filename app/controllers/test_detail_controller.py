from flask import jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.testdetail_model import TestDetail
from app.models.user_model import Usuario

class TestDetailController:
    @staticmethod
    @jwt_required()
    def get_test_details_with_answers():
        try:
            current_user_id = get_jwt_identity()
            user = Usuario.get_user_by_id(current_user_id)

            if user['user_role'] not in ['admin', 'teacher']:
                return jsonify({"message": "Acceso denegado: Usuario sin privilegios suficientes"}), 403

            data = request.get_json() or {}
            test_id = data.get('test_id')

            if not test_id:
                return jsonify({"message": "Por favor, proporciona el ID del test"}), 400

            raw_data = TestDetail.get_by_test_id(test_id)

            if not raw_data:
                return jsonify({"message": "No se encontraron detalles para este test"}), 404

            sections = {}
            for row in raw_data:
                try:
                    section_type = row['section_type']
                    section_desc = row['section_desc']
                    title_id = row['title_id']
                    title_name = row['title_name']
                    title_test = row['title_test']
                    title_type = row['title_type']
                    title_url = row['title_url']
                    question_id = row['question_id']
                    question_text = row['question_text']
                    answer_id = row['answer_id']
                    answer_text = row['answer_text']
                    is_correct = row['is_correct']
                    selected_answer_id = row['selected_answer_id']

                    if section_type not in sections:
                        sections[section_type] = {'section_desc': section_desc, 'titles': {}}

                    if title_id not in sections[section_type]['titles']:
                        sections[section_type]['titles'][title_id] = {
                            'title_name': title_name,
                            'title_test': title_test,
                            'title_type': title_type,
                            'title_url': title_url,
                            'questions': {}
                        }

                    if question_id not in sections[section_type]['titles'][title_id]['questions']:
                        sections[section_type]['titles'][title_id]['questions'][question_id] = {
                            'question_text': question_text,
                            'options': [],
                            'student_answer': None,
                            'correct_answer': None
                        }

                    option = {'option_id': answer_id, 'text': answer_text, 'is_correct': bool(is_correct)}
                    sections[section_type]['titles'][title_id]['questions'][question_id]['options'].append(option)

                    if selected_answer_id and selected_answer_id == answer_id:
                        sections[section_type]['titles'][title_id]['questions'][question_id]['student_answer'] = {
                            'option_id': answer_id,
                            'text': answer_text
                        }

                    if is_correct:
                        sections[section_type]['titles'][title_id]['questions'][question_id]['correct_answer'] = {
                            'option_id': answer_id,
                            'text': answer_text
                        }
                except KeyError as e:
                    print(f"Clave no encontrada en row: {e}, row: {row}")
                    raise
                except Exception as e:
                    print(f"Error procesando fila: {e}, row: {row}")
                    raise

            response_data = []
            for section_type, section_data in sections.items():
                section = {'section_type': section_type, 'section_desc': section_data['section_desc'], 'titles': []}
                for title_id, title_data in section_data['titles'].items():
                    title = {
                        'title_id': title_id,
                        'title_name': title_data['title_name'],
                        'title_test': title_data['title_test'],
                        'title_type': title_data['title_type'],
                        'title_url': title_data['title_url'],
                        'questions': []
                    }
                    for question_id, question_data in title_data['questions'].items():
                        title['questions'].append({
                            'question_id': question_id,
                            'question_text': question_data['question_text'],
                            'options': question_data['options'],
                            'student_answer': question_data['student_answer'],
                            'correct_answer': question_data['correct_answer']
                        })
                    section['titles'].append(title)
                response_data.append(section)

            return jsonify({"data": response_data}), 200

        except Exception as e:
            print(f"Error interno: {str(e)}")
            return jsonify({"error": "Error interno", "details": str(e)}), 500