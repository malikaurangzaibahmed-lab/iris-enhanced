// PASTE THE WORKING SCRIPT HERE
async function scrapeAllCourses() {
    const results = [];

    // 1. Identify all courses from the dashboard table
    const rows = Array.from(document.querySelectorAll('table tbody tr'))
        .filter(r => r.getAttribute('onclick') && r.getAttribute('onclick').includes('SetCourse'));

    console.log(`IRIS Engine: Found ${rows.length} courses to scrape.`);

    for (let row of rows) {
        try {
            const onclick = row.getAttribute('onclick');
            const courseId = onclick.match(/\d+/)[0];
            const cells = row.querySelectorAll('td');

            const courseInfo = {
                id: courseId,
                code: cells[0]?.innerText.trim() || "N/A",
                name: cells[1]?.innerText.trim() || "Unknown",
                teacher: cells[3]?.innerText.trim() || "Unknown"
            };

            console.log(`Scraping: ${courseInfo.code} - ${courseInfo.name}...`);

            // Step A: Set session to this course
            await fetch(`/Courses/SetCourse/${courseId}`);

            // Step B: Fetch Assignments and Quizzes in parallel
            const [assignHtml, quizHtml] = await Promise.all([
                fetch('/Assignments/Index').then(res => res.text()),
                fetch('/Quizzes/Index').then(res => res.text())
            ]);

            // Step C: Parse the HTML into structured JSON
            results.push({
                ...courseInfo,
                assignments: parsePortalTable(assignHtml),
                quizzes: parsePortalTable(quizHtml)
            });

        } catch (e) {
            console.error(`Error scraping course ${row.innerText.split('\t')[0]}:`, e);
        }
    }

    return results;
}

function parsePortalTable(html) {
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');
    const tableRows = Array.from(doc.querySelectorAll('table tbody tr'));

    return tableRows.map(r => {
        if (r.cells.length < 4) return null;
        const title = r.cells[1]?.innerText.trim();
        if (!title || title.toLowerCase().includes("no record found")) return null;

        return {
            title: title,
            startDate: r.cells[2]?.innerText.trim(),
            dueDate: r.cells[3]?.innerText.trim(),
            isActionable: r.innerHTML.toLowerCase().includes('upload') || r.innerHTML.toLowerCase().includes('download')
        };
    }).filter(i => i !== null);
}

// Start execution
scrapeAllCourses().then(data => {
    console.log("FINAL SCRAPE COMPLETE:");
    console.log(JSON.stringify(data, null, 2));
    // This alert confirms the data is ready for the user
    alert(`IRIS Scrape Complete!\nFound data for ${data.length} courses.`);
});