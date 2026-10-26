/* Ćwiczenie 1.2 – pierwszy skrypt Pythona uruchomiony przez SQL Server */

USE LodyPrognoza;
GO
EXEC sys.sp_execute_external_script
     @language = N'Python',
     @script   = N'
import sys
import pandas as pd
import numpy as np
import sklearn
 
print("Python dziala wewnatrz SQL Server!")
print("Wersja Pythona:", sys.version)
 
OutputDataSet = pd.DataFrame({
    "Pakiet": ["python", "pandas", "numpy", "scikit-learn"],
    "Wersja": [sys.version.split()[0], pd.__version__, np.__version__, sklearn.__version__]
})
'
WITH RESULT SETS ((Pakiet nvarchar(50), Wersja nvarchar(50)));
