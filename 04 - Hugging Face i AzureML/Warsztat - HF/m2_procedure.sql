CREATE OR ALTER PROCEDURE sklep.usp_ScoreReviews
    @batch_size INT = 100
AS
BEGIN
    SET NOCOUNT ON;
 
    -- 1. Wybierz tylko opinie, które NIE mają jeszcze wyniku
    DROP TABLE IF EXISTS #ToScore;
 
    SELECT TOP (@batch_size) r.review_id, r.review_text
    INTO   #ToScore
    FROM   sklep.Reviews AS r
    WHERE  NOT EXISTS (SELECT 1 FROM sklep.ReviewSentiment AS s
                       WHERE s.review_id = r.review_id)
      AND  LEN(LTRIM(RTRIM(r.review_text))) > 0
    ORDER BY r.review_id;
 
    -- 2. Nic do zrobienia? Nie uruchamiaj Pythona na pustym zbiorze
    IF NOT EXISTS (SELECT 1 FROM #ToScore)
    BEGIN
        PRINT N'Brak nowych opinii do analizy.';
        RETURN;
    END;
 
    -- 3. Skrypt Pythona: inferencja wsadowa (cała paczka naraz)
    DECLARE @python_script NVARCHAR(MAX) = N'
import os
import pandas as pd
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification
 
MODEL_PATH = r"C:\ProgramData\HF_MODELS\distilbert"
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["HF_HUB_DISABLE_SYMLINKS"] = "1"
 
tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, local_files_only=True)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH, local_files_only=True)
model.eval()
id2label = model.config.id2label
 
ids   = InputDataSet["review_id"].tolist()
texts = InputDataSet["review_text"].tolist()
 
# padding=True wyrównuje długości tekstów, dzięki czemu paczka idzie jednym wywołaniem
inputs = tokenizer(texts, padding=True, truncation=True,
                   max_length=512, return_tensors="pt")
with torch.no_grad():
    probs = F.softmax(model(**inputs).logits, dim=-1)
 
scores, label_ids = torch.max(probs, dim=-1)
 
OutputDataSet = pd.DataFrame({
    "review_id": ids,
    "sentiment": [id2label[i] for i in label_ids.tolist()],
    "score":     [float(s) for s in scores.tolist()]
})
';
 
    -- 4. Zapis wyników; review_id łączy wynik z opinią
    INSERT INTO sklep.ReviewSentiment (review_id, sentiment, score)
    EXEC sp_execute_external_script
        @language          = N'Python',
        @script            = @python_script,
        @input_data_1      = N'SELECT review_id, review_text FROM #ToScore',
        @input_data_1_name = N'InputDataSet';
 
    DECLARE @n INT = @@ROWCOUNT;
    PRINT CONCAT(N'Przeanalizowano opinii: ', @n);
END;
GO
