import os

src_html = r"C:\Users\rapee\Documents\GitHub\cpe_air_remote\slide_canva.html"
with open(src_html, "r", encoding="utf-8") as f:
    content = f.read()

# For slide 1 only: hide slide 2
s1_only = content.replace('<div class="slide" id="slide2">', '<div class="slide" id="slide2" style="display:none;">')
with open(r"C:\Users\rapee\Documents\GitHub\cpe_air_remote\slide1_standalone.html", "w", encoding="utf-8") as f:
    f.write(s1_only)

# For slide 2 only: hide slide 1
s2_only = content.replace('<div class="slide" id="slide1">', '<div class="slide" id="slide1" style="display:none;">')
with open(r"C:\Users\rapee\Documents\GitHub\cpe_air_remote\slide2_standalone.html", "w", encoding="utf-8") as f:
    f.write(s2_only)

print("Created slide1_standalone.html and slide2_standalone.html")
