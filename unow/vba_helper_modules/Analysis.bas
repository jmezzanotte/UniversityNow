Attribute VB_Name = "Analysis"
Sub GetPercents()

    Dim wrkSht As Worksheet
    Dim i As Integer
    
    Set wrkSht = Worksheets("exhibit 2")
   
    For i = 2 To 34
        wrkSht.Cells(i, 3).Value = wrkSht.Cells(i, 2).Value / wrkSht.Range("B35").Value
    Next i

End Sub

Sub AggreUniversity()

    Dim wrkSht As Worksheet
    Dim univTable(0 To 4, 0 To 2) As Variant
    Dim csuFreq, ucFreq, outStateFreq As Integer
    Dim csuPerc, ucPerc, outStatePerc As Double
    Dim aggRng, freqRng, percRng As Range
    Dim funct As WorksheetFunction
    Set wrkSht = Worksheets("exhibit 2")
    Set freqRng = wrkSht.Range("freq")
    Set percRng = wrkSht.Range("percent")
    Set aggRng = wrkSht.Range("code")
    Set funct = Application.WorksheetFunction
    
    
    csuFreq = funct.SumIf(aggRng, "csu", freqRng)
    csuPerc = funct.SumIf(aggRng, "csu", percRng)
    ucFreq = funct.SumIf(aggRng, "uc", freqRng)
    ucPerc = funct.SumIf(aggRng, "uc", percRng)
    outStateFreq = funct.SumIf(aggRng, "out", freqRng)
    outStatePerc = funct.SumIf(aggRng, "out", percRng)
    
    univTable(0, 0) = "College System"
    univTable(0, 1) = "Frequency"
    univTable(0, 2) = "Percent"
    univTable(1, 0) = "California State University"
    univTable(1, 1) = csuFreq
    univTable(1, 2) = Format(csuPerc, "0.0%")
    univTable(2, 0) = "University of California"
    univTable(2, 1) = ucFreq
    univTable(2, 2) = Format(ucPerc, "0.0%")
    univTable(3, 0) = "Out of State"
    univTable(3, 1) = outStateFreq
    univTable(3, 2) = Format(outStatePerc, "0.0%")
    univTable(4, 0) = "Total"
    univTable(4, 1) = csuFreq + ucFreq + outStateFreq
    univTable(4, 2) = Format((csuPerc + ucPerc + outStatePerc), "0.0%")
    
    
    For tableRow = 0 To 4
        For TableCol = 0 To 2
            wrkSht.Cells(tableRow + 40, TableCol + 1) = univTable(tableRow, TableCol)
        Next TableCol
    Next tableRow
    
End Sub

