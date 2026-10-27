EXEC sp_execute_external_script
    @language = N'Python',
    @script = N'
import os
import pandas as pd
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification
 
MODEL_PATH = r"C:\ProgramData\HF_MODELS\distilbert"
os.environ["HF_HUB_OFFLINE"] = "1"
 
tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, local_files_only=True)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH, local_files_only=True)
 
inputs = tokenizer("I really love this workshop!", return_tensors="pt")
probs = F.softmax(model(**inputs).logits, dim=-1)[0]
label_id = int(probs.argmax())
 
OutputDataSet = pd.DataFrame([{
    "label": model.config.id2label[label_id],
    "score": float(probs[label_id])
}])
'
WITH RESULT SETS ((label VARCHAR(20), score FLOAT));
