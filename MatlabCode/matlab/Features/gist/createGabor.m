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


Nscales = length(or);  %Nscales���߶�����=4��
Nfilters = sum(or);  %sum(or)������ͣ�Nfilters��gabor�˲�������=32��

l=0;
for i=1:Nscales
    for j=1:or(i)   %i=1~4,j=1~8
        l=l+1;
        param(l,:)=[.35 .3/(1.85^(i-1)) 16*or(i)^2/32^2 pi/(or(i))*(j-1)]; %paramά����32*4�������ÿ���߶Ⱥ�ÿ��������4���������ٶȶ�4�������Ľ�����ֱ�����˲����ڸ���Ҷ���еľ����ȡ�����λ�á��ǿ�Ⱥͽ�λ��
    end
end

% Frequencies:Ƶ�����
[fx, fy] = meshgrid(-n/2:n/2-1); %���ɶ�ά����fx��fy����128*128����1�е���128�зֱ�Ϊ-64~63
fr = fftshift(sqrt(fx.^2+fy.^2)); %fr��128*128��fftshift���������������Ჿ�ֺ͸����Ჿ�ֵ�ͼ��ֱ���ڸ��Ե����ĶԳ�
t = fftshift(angle(fx+sqrt(-1)*fy)); %p=angle(z)�������㸴��z����λ��p������Ľ��p�������z��ά����ͬ������ֵΪ��������z�е�ÿ��Ԫ�ص���λ�ǣ���λΪ����

% Transfer functions: ���亯��
G=zeros([n n Nfilters]); %G��128*128*32
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

