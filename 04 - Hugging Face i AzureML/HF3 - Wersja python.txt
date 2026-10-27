from sentence_transformers import SentenceTransformer, util

# 1. Ładujemy model embeddingów z Hugging Face
# (możesz podmienić na inny, np. "all-MiniLM-L6-v2", "paraphrase-multilingual-MiniLM-L12-v2", itd.)
model_name = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
print(f"Ładowanie modelu {model_name}... (może to chwilę potrwać)")
model = SentenceTransformer(model_name)
print("Model załadowany pomyślnie!")

# 2. Definiujemy "wzorcowe" opisy chorego i zdrowego pacjenta
prototype_sick = """
Pacjent ma wysoką gorączkę, uporczywy kaszel, silne bóle mięśni i dreszcze.
Wyniki badań krwi są nieprawidłowe, podwyższone markery stanu zapalnego.
Samopoczucie bardzo złe, trudności z oddychaniem.
"""

prototype_healthy = """
Pacjent czuje się dobrze, brak gorączki, brak kaszlu ani bólu.
Badania krwi w normie, brak oznak stanu zapalnego.
Aktywny fizycznie, wysypia się, nie zgłasza istotnych dolegliwości.
"""

# 3. Embeddingi prototypów
emb_sick = model.encode(prototype_sick, convert_to_tensor=True)
emb_healthy = model.encode(prototype_healthy, convert_to_tensor=True)

# 4. Przykładowi pacjenci
patients = [
    {
        "id": "pacjent_1",
        "description": "Od trzech dni ma gorączkę 38.5, suchy kaszel, zmęczenie i bóle mięśni."
    },
    {
        "id": "pacjent_2",
        "description": "Czuje się bardzo dobrze, biega 3 razy w tygodniu, je zdrowo i śpi 8 godzin."
    },
    {
        "id": "pacjent_3",
        "description": "Lekki kaszel od rana, ale brak gorączki, pozostałe parametry w normie."
    }
]

def classify_patient(desc, threshold=0.05):
    """
    Zwraca:
      - 'chory', jeśli opis jest bardziej podobny do chorego
      - 'zdrowy', jeśli opis jest bardziej podobny do zdrowego
      - oraz podobieństwa kosinusowe do obu prototypów.

    threshold – ile punktów różnicy wymagamy, by być "pewnym".
    """
    emb_patient = model.encode(desc, convert_to_tensor=True)

    sim_sick = util.cos_sim(emb_patient, emb_sick).item()
    sim_healthy = util.cos_sim(emb_patient, emb_healthy).item()

    # Scoring / prosta decyzja
    if sim_sick - sim_healthy > threshold:
        label = "chory"
    elif sim_healthy - sim_sick > threshold:
        label = "zdrowy"
    else:
        label = "niejednoznaczne"

    return label, sim_sick, sim_healthy

# 5. Klasyfikujemy pacjentów
if __name__ == "__main__":
    print("\nRozpoczynam klasyfikację pacjentów...\n")
    for p in patients:
        label, sim_sick, sim_healthy = classify_patient(p["description"])
        print(f"=== {p['id']} ===")
        print(f"Opis: {p['description']}")
        print(f"Podobieństwo do 'chorego'   : {sim_sick:.3f}")
        print(f"Podobieństwo do 'zdrowego' : {sim_healthy:.3f}")
        print(f"Decyzja: {label}")
        print()