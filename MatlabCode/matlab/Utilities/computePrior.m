function depthPrior = computePrior( project, trainClips )
%COMPUTEPRIOR Computes a depth prior for DepthTransfer given training files
%
% Input:
%  project    - Project info struct created with initializeProject(...)
%  trainClips - Struct array such that trainClips(i).name contains the 
%               i^{th} training data directory (relative to
%               project.path.data). MATLAB's built in dir() function can 
%               create these structs; ex:
%                   trainClips = ...
%                       dir(fullfile(project.path.data, [BASE_NAME '*']);
%               where BASE_NAME is a name shared by all training 
%               directories
%
% Output:
%  depthPrior - Depth prior result of size [project.h, project.w]
%
%%%%%%%%%%%   Begin computePrior   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Load all depth files from trainClips, average across each clip 
    %加载训练集的depth和mask信息，存入depth和mask，两者大小为project.height*project.width*训练图片数
    depth = zeros(project.h, project.w, numel(trainClips));  %先将两者置0
    mask = zeros(project.h, project.w, numel(trainClips));
    for i=1:numel(trainClips)
        trainName = fullfile(project.path.data, trainClips(i).name);  %每个data/Make3D-Train-文件夹
        [~, depthi, ~, maski] = loadData(trainName, [], [project.h, project.w]);
        if(iscell(depthi))
            depthi = cell2mat(reshape(depthi,1,1,1,[]));
            maski = cell2mat(reshape(maski,1,1,1,[]));
        end
        %Weighted average per video (only use valid depth pixels)
        %------------------------------------------------------------------------------------------
        %any函数作用：判断元素是否为非零元素any(v),如果v是非零元素返回true(即1)否则返回flase(即0)；
        %any(A,dim)中的dim表示的A的维度； 
        %------------------------------------------------------------------------------------------
        mask(:,:,i) = any(maski,4);   %mask(:,:,i)维度为460*345，此语句运行后，每个元素都为1
        depth(:,:,i) = sum(double(maski).*depthi,4)./max(sum(double(maski),4),1);
    end
    %Then average across the entire training set
    depthPrior = sum(double(mask).*depth,3)./max(sum(double(mask),3),1);  %depthPrior大小为project.height*project.width
    %Fill in any holes (very unlikely that the prior contains any though)
    depthPrior(~any(mask,3)) = mean(depth(:));  %如果训练集的深度图中有孔洞，则用其他深度的平均值填充之
end

