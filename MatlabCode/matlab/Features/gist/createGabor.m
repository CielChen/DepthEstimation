function G = createGabor(or, n)
%
% G = createGabor(numberOfOrientationsPerScale, n);
%
% Precomputes filter transfer functions. All computations are done on the
% Fourier domain. 
%
% If you call this function without output arguments it will show the
% tiling of the Fourier domain.
%
% Input
%     numberOfOrientationsPerScale = vector that contains the number of
%                                orientations at each scale (from HF to BF)
%     n = imagesize (square images)
%
% output
%     G = transfer functions for a jet of gabor filters


Nscales = length(or);  %Nscales：尺度数（=4）
Nfilters = sum(or);  %sum(or)：列求和；Nfilters：gabor滤波器数（=32）

l=0;
for i=1:Nscales
    for j=1:or(i)   %i=1~4,j=1~8
        l=l+1;
        param(l,:)=[.35 .3/(1.85^(i-1)) 16*or(i)^2/32^2 pi/(or(i))*(j-1)]; %param维数：32*4，即针对每个尺度和每个方向有4个参数，百度对4个参数的解读：分别控制滤波器在傅里叶域中的径向宽度、径向位置、角宽度和角位置
    end
end

% Frequencies:频域分析
[fx, fy] = meshgrid(-n/2:n/2-1); %生成二维网格，fx和fy都是128*128，第1列到第128列分别为-64~63
fr = fftshift(sqrt(fx.^2+fy.^2)); %fr：128*128；fftshift的作用是让正半轴部分和负半轴部分的图像分别关于各自的中心对称
t = fftshift(angle(fx+sqrt(-1)*fy)); %p=angle(z)函数计算复数z的相位角p，输出的结果p与输入的z的维数相同，返回值为复数数组z中的每个元素的相位角，单位为弧度

% Transfer functions: 传输函数
G=zeros([n n Nfilters]); %G：128*128*32
for i=1:Nfilters
    par=param(i,:);
    tr=t+param(i,4); 
    tr=tr+2*pi*(tr<-pi)-2*pi*(tr>pi);

    G(:,:,i)=exp(-10*param(i,1)*(fr/n/param(i,2)-1).^2-2*param(i,3)*pi*tr.^2);
end


if nargout == 0
    figure
    for i=1:Nfilters
        max(max(G(:,:,i)))
        contour(fftshift(G(:,:,i)),[1 .7 .6],'r');
        hold on
        drawnow
    end
    axis('on')
    axis('square')
    axis('ij')
end

