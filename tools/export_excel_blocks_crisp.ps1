$excelPath = "D:\Iris Working backup\MOST RECENT\IRIS\assets\documents\Date_Sheet_FINAL_Term_Exam_FALL_2025 - Version I - 08-12-25.xlsx"
$artifactDir = "C:\Users\MALIK\.gemini\antigravity-ide\brain\83f6734c-1364-4521-80ff-f595797d00c4"

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

$wb = $excel.Workbooks.Open($excelPath)
$ws = $wb.Worksheets.Item(1)

# Block ranges:
# Block 1 (A & WCR): Cols A to L (Rows 1 to 20)
# Block 2 (B): Cols M to Z (Rows 1 to 20)
# Block 3 (C): Cols AA to AO (Rows 1 to 20)
# Block 4 (D): Cols AP to BA (Rows 1 to 20)

$blocks = @(
    @{ Name = "block1_A_WCR"; Range = "A1:L25" },
    @{ Name = "block2_B_MGMT"; Range = "M1:Z25" },
    @{ Name = "block3_C_CS"; Range = "AA1:AO25" },
    @{ Name = "block4_D_ENG"; Range = "AP1:BA25" }
)

foreach ($b in $blocks) {
    $rName = $b.Name
    $rAddress = $b.Range
    $outPdf = Join-Path $artifactDir "excel_${rName}.pdf"
    
    $ws.PageSetup.PrintArea = $rAddress
    $ws.PageSetup.Orientation = 2 # Landscape
    $ws.PageSetup.Zoom = 100 # Full 100% crisp zoom
    $ws.PageSetup.FitToPagesWide = 1
    $ws.PageSetup.FitToPagesTall = 1
    
    $ws.ExportAsFixedFormat(0, $outPdf)
    Write-Host "Exported Block: $outPdf"
}

$wb.Close($false)
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
