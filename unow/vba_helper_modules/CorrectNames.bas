Attribute VB_Name = "CorrectNames"
Sub FixCase()

    Dim rng, oCell As Range
    Dim funct As WorksheetFunction
    Dim wrkSht As Worksheet
    
    Set wrkSht = Worksheets("exhibit 3")
    Set funct = Application.WorksheetFunction
    Set rng = Selection
    
    For Each oCell In rng
        oCell.Value = funct.Proper(oCell.Value)
    Next oCell
    
    

End Sub

