%DEMODEPTHTRANSFER This script shows the proper usage of DepthTransfer, 
% and how to create testing and training data
%
EXAMPLES_DIR = 'examples'; %Example directory in root of DepthTransfer
%
%%%%%%%%%%%   Begin demoDepthTransfer   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Initialize a new project (sets up paths, parameters, etc)
h = 460; w = 345; %Inferred depth resolution (output)
Cv = 7; %Number of candidate videos to use for training
Cf = 1; %Number of candidate frames from each video
project = initializeProject(Cv, Cf, [h,w]);

%% Create training data
fprintf('Preparing training data...'); prepTrainTime = tic;
trainFilesDir = fullfile(EXAMPLES_DIR, 'sample_training_data');  %训练数据路径
trainFiles = dir(fullfile(trainFilesDir, 'img-*.jpg'));  %训练集中的图片
%parfor实现了MATLAB的并行计算
%以下parfor创建了data文件夹中的Make3D-Train-子文件夹及其所含内容
parfor i=1:numel(trainFiles)
    tmpProject = project; %Avoid parfor slicing issue
    [~, name, ~] = fileparts(fullfile(trainFilesDir, trainFiles(i).name));
    basename = name(5:end); %Remove 'img-' prefix
    dataDirName = fullfile(tmpProject.path.data,['Make3D-Train-' basename]);  %创建data文件夹中的Make3D-Train-子文件夹
    if( exist(fullfile(dataDirName, '001'), 'dir') )  %判断'Make3D-Train-'文件夹中是否存在‘001’文件夹
        continue; %Training data already exists
    end
    img = imread(fullfile(trainFilesDir, trainFiles(i).name));  %读入example/sample_training_data文件夹中的每张训练图片（.jpg)
    %--------------------------------------------------------------------------
    %dir函数获得指定文件夹下的所有子文件夹和文件,并存放在在一种为文件结构体数组中
    %--------------------------------------------------------------------------
    depthFile = dir( fullfile(trainFilesDir, ['depth_sph_corr-' basename '.mat']) );  %将example/sample_training_data文件夹中的所有depth_sph_.mat文件存入depthFile
    foo = load( fullfile(trainFilesDir, depthFile(1).name) );  %载入每个depth_sph_.mat文件
    %depth_sph_.mat文件包含Position3DGrid，Position3DGrid大小为55*305*4，其中(:,:,4)是深度
    depth = foo.Position3DGrid(:,:,4); %Load only depth from laser data  %最后一维是深度
    createData(dataDirName, img, depth, [], false); %false => verbose off
end
fprintf('done. [%6.02fs]\n', toc(prepTrainTime));

%% Create test data for example 1 image (unless it already exists)
img = im2double(imread(fullfile(EXAMPLES_DIR,'demo_data','img-op57-p-016t000.jpg')));  %打开example/demo_data文件夹中的测试图片（.jpg)
if( ~exist(fullfile(project.path.data,'demo','001'), 'dir') ) %创建data文件夹中的demo文件夹及其子文件
    createData(fullfile(project.path.data,'demo'), img);
end

%% Depth transfer
%Set which data to train with
trainFiles = dir(fullfile(project.path.data, 'Make3D-Train*'));
testFile = fullfile('demo', '001');
%Compute prior (average training depth). To save time for future runs, here
% we precompute and store the prior (training data must stay constant).
if( exist(fullfile(EXAMPLES_DIR,'sample_training_prior.mat'), 'file') )
    load(fullfile(EXAMPLES_DIR,'sample_training_prior.mat'));
else
    fprintf('Computing depth prior...'); testTime = tic;
    depthPrior = computePrior(project, trainFiles);
    save(fullfile(EXAMPLES_DIR,'sample_training_prior.mat'), 'depthPrior');
    fprintf('done.   [%6.02fs]\n', toc(testTime));
end
%Set the motion segmentation function here. Since this is a single image, 
% we actially don't need one. See 'examples' directory for using these
% functions, or depthTransfer.m for documentation and available
% segmentation functions
motionFunc = [];
%Run depth transfer
depthEst = depthTransfer(project, testFile, trainFiles, depthPrior, motionFunc);

%% Display results
img = imresize(img,[project.h,project.w]);
NdepthEst = repmat(imnormalize(depthEst),[1,1,3,1]); %Normalize/add channels for visualization
imshow([img, NdepthEst]);
