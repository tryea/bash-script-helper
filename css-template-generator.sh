#!/bin/bash

# Set filename and file path
filename=${1:-"generated.css"}
filepath=${2:-"."}

# Full path
fullpath="$filepath/$filename.css"

cat > $fullpath << EOF
/* 
  Default styles: Mobile First Approach
  Target devices: Mobile devices (portrait)
*/
body {
  /* styles */
}

/* 
  @media only screen and (min-width: 600px) and (max-width: 768px)
  Target devices: Tablets (portrait), large mobile devices (landscape)
*/
@media only screen and (min-width: 600px) and (max-width: 768px) {
  body {
    /* styles */
  }
}

/* 
  @media screen and (min-width: 769px) and (max-width: 1023px)
  Target devices: Tablets (landscape), small laptops
*/
@media screen and (min-width: 769px) and (max-width: 1023px) {
  body {
    /* styles */
  }
}

/* 
  @media screen and (min-width: 1024px) and (max-width: 1440px)
  Target devices: Desktops, large laptops
*/
@media screen and (min-width: 1024px) and (max-width: 1440px) {
  body {
    /* styles */
  }
}

/* 
  @media screen and (min-width: 1441px)
  Target devices: Large desktops, TVs, etc.
*/
@media screen and (min-width: 1441px) {
  body {
    /* styles */
  }
}
EOF

echo "CSS file has been created at $fullpath"
