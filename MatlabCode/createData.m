function createData( dataDirectory, img, depth, holeMask, verbose )
%CREATEDATA Reformats and saves data that DepthTransfer code expects
%
% Input:
%  dataDirectory - directory to save data (img, depth, etc) to [string]
%  img           - 4D img/video data [height x width x {1,3} x numFrames] 
%                  OR a cell array of 4D video clips (use cell format if 
%                  video should be split into smaller clips)
%  depth(=[])    - 4D depth data [height x width x 1 x numFrames] OR a
%                  cell array of 4D depth clips. Can also be formatted as 
%                  3D (without singleton dim). img and depth do NOT need to
%                  have the same height or width (but numFrames should be 
%                  the same though)
%  holeMask(=[]) - 4D binary hole data [height x width x 1 x numFrames] OR 
%                  a cell array of 4D hole info (should be consistent with
%                  depth). Use this variable if depth contains known pixels 
%                  of missing information (pixels == 0 will be 
%                  interpolated), otherwise disregard it or leave it as 
%                  empty ([]). Can also be formatted as 3D (without 
%                  singleton dim)
%  verbose(=true)- Print timing/debug information (default is true)
%    
% Note: To achieve temporal consistency and motion estimation, optical 
%   flow must be computed between neighboring frames. We use the publicly 
%   available optical flow code from Ce Liu, found here:
%   http://people.csail.mit.edu/celiu/OpticalFlow/
%   opticalflow.m (found in this directory) provides an interface for Liu's
%   code. To use any other optical flow module, either edit opticalflow.m,
%   or modify opticalFlowFunc to point to your own flow function (make sure
%   the output data format is the same as in opticalflow.m).
%   Set opticalFlowFunc = [] if you do not need flow (i.e. running on
%   single images).
opticalFlowFunc = @opticalflow;
%
%%%%%%%%%%%   Begin createData   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Convert everything to cell arrays
    if( ~iscell(img) )
        img = {img}; %将img转为cell形式
        %将depth转为cell形式，如果输入没有depth，则创建一个cell形式的depth，并置空
        if( ~exist('depth', 'var') )   
            depth = {[]};
        else
            depth = {depth};
        end
        %将holeMask转为cell形式，如果输入没有holeMask，则创建一个cell形式的holeMask，并置空
        if( ~exist('holeMask', 'var') )  
            holeMask = {[]};   
        else
            holeMask = {holeMask};
        end
    end
    if( ~exist('depth', 'var') )
        depth = repmat({[]}, size(img));
    end
    if( ~exist('holeMask', 'var') )
        holeMask = repmat({[]}, size(img));
    end
    if( ~exist('verbose', 'var') )  %如果输入没有verbos，则默认verbose=true
        verbose = true;
    end
    
    %Input validation
    [h,w,d,~] = size(img{1});  %第一张图片的height，width，通道数
    [h2,w2,~,~] = size(depth{1});  %第一张深度图的height，width
    for i=1:numel(img)
        [hi,wi,~,Ki] = size(img{i});   %第i张图片的height，width，Ki=1
        assert(h==hi && w==wi, 'Input dimension mismatch (clip #%03d)\n', i);
        if( isempty(depth{i}) && isempty(holeMask{i})  )  %如果第i张图片的depth和holeMask为空，则置depth为0，置holeMask为1，且两者大小均为img.height*img.width
            depth{i} = zeros(h,w,Ki);  
            holeMask{i} = true(h,w,Ki);  
        elseif( isempty(holeMask{i}) ) %如果只是第i张图片的holeMask为空，则置holeMask为1，大小为depth（1）.height*depth（1）.width
            holeMask{i} = true(h2,w2,Ki);
        else  %如果第i张图片的depth和holeMask都非空，则让它们的大小均为depth（1）.height*depth（1）.width
            try 
                depth{i} = reshape(depth{i}, [h2,w2,Ki]);
                holeMask{i} = reshape(holeMask{i}, [h2,w2,Ki]);
            catch %#ok<CTCH>
                error('depth and holeMask must have same dimensions (clip #%03d)\n', i);
            end
        end
    end
    
    %Create output dir 创建测试集目录，并建立info.mat
    if( ~exist(dataDirectory,'dir') )
        mkdir(dataDirectory);
        clips = [];
        save(fullfile(dataDirectory,'info.mat'), 'clips');
    else
        warning('%s already exists. Adding data as additional clip(s).\n', dataDirectory); %#ok<WNTAG>
        foo = load(fullfile(dataDirectory,'info.mat'));
        clips = foo.clips;
    end
    
    %Save data
    if(verbose), fprintf('Creating DepthTransfer data at: %s\n', dataDirectory); end
    for i=1:numel(img)
        nc = numel(clips) + 1;
        if(verbose), fprintf('Processing clip %03d\n', nc); end
        K = size(img{i},4);  %K=1
        
        %Compute optical flow (if necessary) 单幅图不用计算光流
        if(verbose), fprintf('\tComputing optical flow...'); flowtime = tic; end
        flow = zeros(h,w,2,K);  %flow大小：img.height*img.width*2
        if( ~isempty(opticalFlowFunc) )
            tmpimg = img{i};
            tmpimg_next = img{i}(:,:,:,2:K);
            parfor j=1:K-1
                flow(:,:,:,j) = opticalFlowFunc(tmpimg(:,:,:,j), tmpimg_next(:,:,:,j));
            end
        end
        if(verbose), fprintf('done. [%6.02fs]\n', toc(flowtime)); end
        
        %Fill depth holes (if necessary) 只有当holeMask中含0时，才要填充深度图中的孔洞
        if( any(holeMask{i}(:)==0) )
            if(verbose), fprintf('\tFilling depth holes...'); filltime = tic; end
            img_resize = reshape(imresize(img{i}, [h2,w2], 'bilinear'), [h2,w2,d,K]);
            depth_filled = fillDepthHoles(img_resize, depth{i}, flow, holeMask{i});
            if(verbose), fprintf('done. [%6.02fs]\n', toc(filltime)); end
        else
            depth_filled = depth{i};
        end
        
        %Write data 
        if(verbose), fprintf('\tSaving data...'); savetime = tic; end
        %将信息填入clip，并建立各个文件夹：img,depth0,depth,flow,mask
        clipInfo.name = sprintf('%03d', nc);
        clipInfo.size = [h,w];
        clipInfo.numFrames = K;
        clipInfo.imgDir = 'img';
        clipInfo.depth0Dir = 'depth0';
        clipInfo.depthDir = 'depth';
        clipInfo.flowDir = 'flow';
        clipInfo.maskDir = 'mask';
        clipInfo.flow_bounds = [min(flow(:)), max(flow(:))];
        clipInfo.depth0_bounds = [min(depth{i}(:)), max(depth{i}(:))];
        clipInfo.depth_bounds = [min(depth_filled(:)), max(depth_filled(:))];
        clips{nc} = clipInfo; %#ok<AGROW>
        mkdir(fullfile(dataDirectory, clipInfo.name));
        mkdir(fullfile(dataDirectory, clipInfo.name, clipInfo.imgDir));
        mkdir(fullfile(dataDirectory, clipInfo.name, clipInfo.depth0Dir));
        mkdir(fullfile(dataDirectory, clipInfo.name, clipInfo.depthDir));
        mkdir(fullfile(dataDirectory, clipInfo.name, clipInfo.flowDir));
        mkdir(fullfile(dataDirectory, clipInfo.name, clipInfo.maskDir));
        %Convert floating point images to 16 bit uints
        depth0 = uint16(round(65535.*imnormalize(depth{i}))); %先将图片归一化，再将double浮点型转换为uint16无符号整型 
        depth_filled = uint16(round(65535.*imnormalize(depth_filled)));
        %C = cat(dim, A, B)：按dim来联结A和B两个数组
        %flow:height*width*2,flow3:height*width*3
        flow3 = cat(3, imnormalize(flow), zeros(h,w,1,K));  
        flow3 = uint16(round(65535.*flow3));
        %Make sure holeMask is stored as 1 bit
        %logical函数是把数值变成逻辑值，logical(x)将把x中的非0的值变成1，把所有的数值0值变成逻辑0
        %~=不等于
        holeMask{i} = logical(holeMask{i}~=0);
        for j=1:K
            %将img.jpg,depth0.jpg,depth/jpg,flow.jpg,mask.jpg分别写入各自的文件夹
            namej = sprintf('%04d.png', j-1);
            imwrite(img{i}(:,:,:,j), fullfile(dataDirectory, clipInfo.name, clipInfo.imgDir, namej));
            imwrite(depth0(:,:,j), fullfile(dataDirectory, clipInfo.name, clipInfo.depth0Dir, namej));
            imwrite(depth_filled(:,:,j), fullfile(dataDirectory, clipInfo.name, clipInfo.depthDir, namej));
            imwrite(flow3(:,:,:,j), fullfile(dataDirectory, clipInfo.name, clipInfo.flowDir, namej));
            imwrite(holeMask{i}(:,:,j), fullfile(dataDirectory, clipInfo.name, clipInfo.maskDir, namej));
        end
        %Save info struct
        save(fullfile(dataDirectory,'info.mat'), 'clips'); %将clip中的数据存入info.mat
        if(verbose), fprintf('done. [%6.02fs]\n', toc(savetime)); end
    end
end

