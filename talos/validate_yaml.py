import yaml
import sys

# Le nom du fichier à vérifier
file_to_check = 'manifests/kubernetes-dashboard.yaml'

print(f"--- Checking file: {file_to_check} ---")

try:
    with open(file_to_check, 'r') as f:
        # Essayer de charger tous les documents YAML
        docs = list(yaml.safe_load_all(f))
    
    print(f"\nSUCCESS: YAML syntax is valid.")
    print(f"Successfully loaded {len(docs)} documents from the file.")

except yaml.YAMLError as e:
    print(f"\nERROR: Found a YAML syntax error.")
    
    # Afficher le contexte si disponible
    if hasattr(e, 'problem_mark'):
        mark = e.problem_mark
        line_num = mark.line + 1  # Les lignes sont indexées à partir de 0
        col_num = mark.column + 1
        
        print(f"Description: {e.problem}")
        print(f"Location: Line {line_num}, Column {col_num}")
        print("\n--- Context (5 lines before and after error) ---")
        
        try:
            with open(file_to_check, 'r') as f:
                lines = f.readlines()
            
            # Définir la fenêtre de lignes à afficher
            start = max(0, mark.line - 5)
            end = min(len(lines), mark.line + 6)
            
            for i in range(start, end):
                line_content = lines[i].rstrip('\n')
                current_line_num_display = i + 1
                
                # Ajouter un pointeur sur la ligne exacte de l'erreur
                if i == mark.line:
                    print(f"{current_line_num_display:5d} >> | {line_content}")
                else:
                    print(f"{current_line_num_display:5d}    | {line_content}")
            print("--- End Context ---\n")

        except Exception as read_error:
            print(f"Could not read file to provide context: {read_error}")

except FileNotFoundError:
    print(f"\nERROR: File not found at '{file_to_check}'. Please check the path.")
    
    