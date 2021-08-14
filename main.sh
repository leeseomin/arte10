parallel --no-notice rm -r ::: s1/* s2/* s3/* s4/* s5/* s6/* s7/* s8/* s9/* s10/* s11/* s12/* s13/*
parallel --no-notice rm -r ::: s14/* s15/* s16/* s17/* s18/* s19/* s20/* s21/* s22/* s23/* s24/* s25/*
parallel --no-notice rm -r ::: s26/* s27/* s28/* s29/* s30/* s31/* s32/* s33/* s34/* s35/* s36/* s37/* s38/*
cd s
for f in *\ *; do mv "$f" "${f// /_}"; done
cd s
parallel convert {} -resize 2000x2000 {.}.png ::: *.* 
rm *.jpg
rm *.JPG
parallel convert {} ../s25/{} ::: *.*
cd ..
cd s
for i in *.* 
do
gmic -input $i -gtutor_fpaint 0.5,0.5,0,0,45,0.5,0.5,0.5,0 -o ../s1/$i 
done
cd ..
cd s1
for i in *.* 
do 
convert $i ../s/$i -alpha set  -compose softlight -composite ../s2/$i 
done 
cd ..
cd s2
parallel gmic {} -fx_AbstractFlood 1,10,7,2,0,10,5,3,255,255,255,255,0,300,10,90,0.7,0,0,0 -o ../s5/{} ::: *.*
cd ..
cd s5
parallel gmic {} -fx_unsharp 1,1.25,10,2,0,1,1,1,0,0,0,50,50 -o ../s17/{} ::: *.*
cd ..
cd s17
for i in *.* 
do
gmic -input $i -gtutor_fpaint 0.5,0.5,0,0,45,0.5,0.5,0.5,0 -o ../s1/$i 
done
cd ..
cd s1
for i in *.* 
do 
convert $i ../s17/$i -alpha set  -compose darken -composite ../s5/$i 
done 
cd ..
cd s5
parallel convert {} -flop  ../s6/{} ::: *.* 
cd ..
cd s6
for i in *.* 
do 
convert $i ../s5/$i -alpha set  -compose pinlight -composite ../s8/$i 
done 
cd ..
cd s8
parallel gmic {} -fx_pixelsort 1,2,0,1,0,100,0,0,0 -o ../s9/{} ::: *.*
cd ..
cd s9
parallel convert {}  -set filename:new  ../s24/"%tm5b" "%[filename:new].png" ::: *.*
cd ..
cd s9
parallel gmic {} -fx_pixelsort 1,3,2,1,0,100,0,0,0 -o ../s12/{} ::: *.*
cd ..
cd s12
parallel convert {}  -set filename:new  ../s24/"%tm5c" "%[filename:new].png" ::: *.*
cd ..
cd s12
parallel gmic {} -fx_pixelsort 0,2,2,1,0,100,0,0,0 -o ../s13/{} ::: *.*
cd ..
cd s13
parallel convert {}  -set filename:new  ../s24/"%tm5d" "%[filename:new].png" ::: *.*
cd ..
cd s12
parallel gmic {} -fx_pixelsort 1,3,0,1,0,100,0,0,0 -o ../s14/{} ::: *.*
cd ..
cd s14
parallel convert {}  -set filename:new  ../s24/"%tm5a" "%[filename:new].png" ::: *.*
cd ..
cd s8
parallel gmic {} -fx_pixelsort 1,3,2,1,0,100,0,0,0 -o ../s12/{} ::: *.*
cd ..
cd s12
parallel convert {}  -set filename:new  ../s24/"%tm5h" "%[filename:new].png" ::: *.*
cd ..
parallel --no-notice rm -r ::: s1/* s2/* s3/* s4/* s5/* s6/* s7/* s8/* s9/* s10/* s11/* s12/* s13/*
parallel --no-notice rm -r ::: s14/* s15/* s16/* s17/* s18/* s19/* s20/* s21/* s22/* s23/*
cd s24
for i in *.* 
do 
convert -modulate 100,250,100 $i ../s1/$i
done
cd ..
cd s1
for i in *.* 
do
gmic -input $i -fx_blur_bloom 1,2,3,2,0,0,0,0,7,0 -o ../s2/$i
done
cd .. 
cd s2
for i in *.* 
do 
convert $i ../s24/$i -alpha set -channel A -evaluate set 100% -compose softlight -composite ../s3/$i 
done 
cd .. 
cd s3
for i in *.* 
do
gmic -input $i -fx_poster_edges 20,60,5,0,10,0,0,0 -o ../s4/$i 
done
cd .. 
cd s4
for i in *.*; do
   convert $i  -set filename:new ../s25/"%tcpu2" "%[filename:new].png"
done
cd ..
cd s3
for i in *.* 
do 
gmic -input $i -fx_AbstractFlood 1,10,7,2,0,10,5,3,255,255,255,255,0,300,10,90,0.7,0,0,0 -o ../s6/$i 
done
cd .. 
cd s6
for i in *.*; do
   convert $i  -set filename:new ../s25/"%tcpu1" "%[filename:new].png"
done
cd ..
cp s24/*.*  s25
cd s6
parallel gmic {} -fx_euclidean2polar 50,50,1,1,1 -o ../s15/{} ::: *.*
cd .. 
cd s15
for i in *.*; do
   convert $i  -set filename:new ../s25/"%tcpu1eu" "%[filename:new].png"
done


