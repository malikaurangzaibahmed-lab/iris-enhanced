(async function runFullPortalCrawl() {
    console.log("🚀 Starting Full Data Extraction...");

    const fetchDOM = async (url) => {
        const res = await fetch(url);
        const text = await res.text();
        return new DOMParser().parseFromString(text, 'text/html');
    };

    try {
        const rows = Array.from(document.querySelectorAll('table tbody tr[onclick*="SetCourse"]'));
        if (rows.length === 0) return console.error("❌ No courses found.");

        const masterData = {
            student: document.querySelector('.welcome_msg')?.innerText.replace(/Welcome\s*:/i, '').trim() || "Student",
            extractedAt: new Date().toISOString(),
            totalCourses: rows.length,
            courses: []
        };

        for (const row of rows) {
            const courseId = row.getAttribute('onclick').match(/\/SetCourse\/(\d+)/)?.[1];
            if (!courseId) continue;

            const course = {
                code: row.cells[0]?.innerText.trim(),
                name: row.cells[1]?.innerText.trim(),
                credits: row.cells[2]?.innerText.trim(),
                instructor: row.cells[3]?.innerText.trim(),
                attendance: row.cells[5]?.innerText.trim(),
                assignments: [],
                quizzes: []
            };

            // Switch session to this course
            await fetch(`/Courses/SetCourse/${courseId}`);

            // Fetch sub-data
            const [aDoc, qDoc] = await Promise.all([
                fetchDOM('/Assignments/Index'),
                fetchDOM('/Quizzes/Index')
            ]);

            const parseTable = (doc) => Array.from(doc.querySelectorAll('table tbody tr'))
                .filter(r => r.cells.length > 3 && !r.innerText.includes('No record'))
                .map(r => ({
                    title: r.cells[1]?.innerText.trim(),
                    due: r.cells[3]?.innerText.trim(),
                    status: r.innerHTML.toLowerCase().includes('upload') ? 'OPEN' : 'CLOSED'
                }));

            course.assignments = parseTable(aDoc);
            course.quizzes = parseTable(qDoc);
            masterData.courses.push(course);
            console.log(`✅ Fully Synced: ${course.name}`);
        }

        const finalJSON = JSON.stringify(masterData, null, 2);
        await navigator.clipboard.writeText(finalJSON);

        console.log("🏁 EXTRACTION COMPLETE. Full data is now in your CLIPBOARD.");
        console.dir(masterData); // Click the arrow in the console to expand everything
        alert(`Success! Extracted ${rows.length} courses. Paste the result into your editor.`);

    } catch (err) {
        console.error("❌ Failed:", err);
    }
})();