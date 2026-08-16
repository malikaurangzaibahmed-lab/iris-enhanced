$excelFiles = @(
    "D:\Iris Working backup\MOST RECENT\IRIS\assets\documents\Date_Sheet_FINAL_Term_Exam_FALL_2025 - Version I - 08-12-25.xlsx",
    "D:\Iris Working backup\MOST RECENT\IRIS\assets\documents\Version I of Date Sheet Mid Term Exam SPRING 2026 25-03-2026.xlsx"
)

$artifactDir = "C:\Users\MALIK\.gemini\antigravity-ide\brain\83f6734c-1364-4521-80ff-f595797d00c4"

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

foreach ($file in $excelFiles) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
    $cleanName = $baseName -replace '[^a-zA-Z0-9_]', '_'
    $pdfPath = Join-Path $artifactDir "real_excel_${cleanName}.pdf"
    
    Write-Host "Opening in Microsoft Excel: $file"
    $wb = $excel.Workbooks.Open($file)
    $ws = $wb.Worksheets.Item(1)
    
    # Page setup to fit sheet on wide landscape orientation so it matches Excel exactly
    $ws.PageSetup.Orientation = 2 # xlLandscape
    $ws.PageSetup.Zoom = $false
    $ws.PageSetup.FitToPagesWide = 1
    $ws.PageSetup.FitToPagesTall = $false
    
    # Export to PDF (0 = xlTypePDF)
    $ws.ExportAsFixedFormat(0, $pdfPath)
    Write-Host "Successfully exported native Microsoft Excel PDF: $pdfPath"
    
    $wb.Close($false)
}

$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "COMPLETED NATIVE EXCEL EXPORT"
