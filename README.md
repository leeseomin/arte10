# arte10



### Dependency install on ubuntu 20.04 


```
 # parallel install
 
 sudo apt install parallel
 
 
   #  gimp gmic install

sudo add-apt-repository ppa:otto-kesselgulasch/gimp-edge

sudo apt-get update

sudo apt-get install gmic gimp-gmic


 #   imagemagick install

sudo apt install graphicsmagick-imagemagick-compat

sudo apt install imagemagick-6.q16


 #  Gmic update filters (follow the link)
 
https://telegra.ph/Gmic-update-filters-07-26

```



### Install

```

git clone https://github.com/leeseomin/arte10

cd arte10

mkdir s{1..25}


```

### Usage
```

input images folder : s ,   result folder : s25


bash main.sh   

```


###  Input images from 

https://drive.google.com/file/d/17LY2aN8OiH6f0ebwlCW4armlsfmVnaZD/view?usp=sharing



###  Results

### input image1
 <img src="https://github.com/leeseomin/arte10/blob/main/s/modi.png" width="600">
 
### output image1
 <img src="https://github.com/leeseomin/arte10/blob/main/out/mo1.png" width="2000">
 <img src="https://github.com/leeseomin/arte10/blob/main/out/mo2.png" width="2000">
 <img src="https://github.com/leeseomin/arte10/blob/main/out/mo3.png" width="2000">




### input image2
 <img src="https://github.com/leeseomin/arte10/blob/main/s/egon.png" width="500">

### output image2
 <img src="https://github.com/leeseomin/arte10/blob/main/out/eg1.png" width="2000">
 <img src="https://github.com/leeseomin/arte10/blob/main/out/eg2.png" width="2000">
 <img src="https://github.com/leeseomin/arte10/blob/main/out/eg3.png" width="2000">
 <img src="https://github.com/leeseomin/arte10/blob/main/out/eg4.png" width="2000">


### input image3
 <img src="https://github.com/leeseomin/arte10/blob/main/s/cafe.png" width="500">

### output image3
 <img src="https://github.com/leeseomin/arte10/blob/main/out/ca1.png" width="2000">
 <img src="https://github.com/leeseomin/arte10/blob/main/out/ca2.png" width="2000">
 <img src="https://github.com/leeseomin/arte10/blob/main/out/ca3.png" width="2000">


 ### input image4
 <img src="https://github.com/leeseomin/arte10/blob/main/s/399.png" width="500">

### output image4
 <img src="https://github.com/leeseomin/arte10/blob/main/out/3a.png" width="2000">
 <img src="https://github.com/leeseomin/arte10/blob/main/out/3b.png" width="2000">
 <img src="https://github.com/leeseomin/arte10/blob/main/out/3c.png" width="2000">
 <img src="https://github.com/leeseomin/arte10/blob/main/out/3d.png" width="2000">

 
 
### make animated png result
```
ffmpeg -framerate 1 -pattern_type glob -i '*.png' \
  -c:v libx264 out.mp4
  
  
ffmpeg -i out.mp4 -plays 0  apngout.apng
  
```  
  
  

### License

This repo is made freely available to academic and non-academic entities for non-commercial purposes such as academic research, teaching, scientific publications. Permission is granted to use the arte10 given that you agree to my license terms. Regarding the request for commercial use, please contact me via email (leeseomin@gmail.com)



###  Author

LEE SEOMIN
