# Sample English OCR trial

Source: attached screenshot, not a complete PDF.
Engine: local macOS Apple Vision, accurate recognition, en-US, language correction enabled.

- sample-raw.txt: unmodified recognized text, retaining recognized line breaks.
- sample-cleaned.txt: manually reviewed against the screenshot; joined wrapped lines, joined non-corporeal, restored visible punctuation, and removed the stray bullet after “in”.

The source ends mid-sentence at “a mental”; no continuation was invented. The marked word “unmixed” is partly obscured and should be checked against the original PDF.

The cleaned UTF-8 TXT file is compatible with Booklet's TxtImporter. This trial does not add OCR to Booklet or validate full-PDF processing, mixed scripts, or whole-book accuracy.
