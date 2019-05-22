# Memory & Leak Testing Tools

These tools simplify and extend popular memory and leak testing tools such as [valgrind](valgrind.org) and [clang's Address Sanitizer](https://github.com/google/sanitizers/wiki/AddressSanitizer).  

The approach taken is to post-process the tools' output to provide additional capabilities.  This also allows reports to be suppressed after the fact, rather than having to be done at the time the test is run.

- You can run the scripts on multiple report files at one time, and redirect the summary output to a file.  We use this capabiRe: MALLOC_CHECK_lity to process all the individual valgrind files from a single test run in "one swell foop".
- The scripts assign a unique ID to each leak or memory error, based on its stack trace.  This makes it possible to track leaks and errors across different processes, software versions and test runs.
 - The scripts massage the stack trace so that similar stacks will generate the same ID even if there are minor differences.  They also resolve differences between gcc and clang.
- The scripts allow for filtering leaks and errors based on their unique ID.  This allows you to suppress reports more easily, and at a finer level of detail.  
- You can specify that any one-time leaks be ignored automatically.
- You can also filter specific leaks based on a count of occurences, so you can ignore leaks that occur a small number of times, e.g., at process startup.  If the leak count exceeds the limit, it will be reported.
- You can ignore stack traces that don't match a set of regex's.  This lets you filter out leak and memory errors from "naughty" software (like the JVM) that otherwise would create a lot of useless reports, when there is no application code on the stack.
- You can filter leaks based on valgrind's "indirectly lost", "possibly lost" and "still reachable" categories.  This means that you will typically want to capture everything and filter it later.
 - The different categories generate the same leak ID's, and are combined for the purpose of counting occurences.

# Installation
Simply clone the repo and add the `scripts` directory to your `PATH`:

```
cd <dir>
git clone https://github.com/nyfix/memleaktest.git
export PATH=<dir>/memleaktest/scripts:${PATH} 
```

## Notes
- Requires gnu awk (gawk) 4.1 or later
- For Mac, need to install gnu awk -- e.g.:

   ```
   brew install gawk
   ```

# Documentation
Documentation can be found in the [wiki](https://github.com/nyfix/memleaktest/wiki).

# Credits
The initial scripts were created by Bill Mott, and subsequently modified and enhanced by Kwong Kit Wong, Tilak Singh and Bill Torpey.

