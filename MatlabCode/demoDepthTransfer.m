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
trainFilesDir = fullfile(EXAMPLES_DIR, 'sample_training_data');  %ѵ������·��
trainFiles = dir(fullfile(trainFilesDir, 'img-*.jpg'));  %ѵ�����е�ͼƬ
%parforʵ����MATLAB�Ĳ��м���
%����parfor������data�ļ����е�Make3D-Train-���ļ��м�����������
parfor i=1:numel(trainFiles)
    tmpProject = project; %Avoid parfor slicing issue
    [~, name, ~] = fileparts(fullfile(trainFilesDir, trainFiles(i).name));
    basename = name(5:end); %Remove 'img-' prefix
    dataDirName = fullfile(tmpProject.path.data,['Make3D-Train-' basename]);  %����data�ļ����е�Make3D-Train-���ļ���
    if( exist(fullfile(dataDirName, '001'), 'dir') )  %�ж�'Make3D-Train-'�ļ������Ƿ���ڡ�001���ļ���
        continue; %Training data already exists
    end
    img = imread(fullfile(trainFilesDir, trainFiles(i).name));  %����example/sample_training_data�ļ����е�ÿ��ѵ��ͼƬ��.jpg)
    %--------------------------------------------------------------------------
    %dir�������ָ���ļ����µ��������ļ��к��ļ�,���������һ��Ϊ�ļ��ṹ��������
    %--------------------------------------------------------------------------
    depthFile = dir( fullfile(trainFilesDir, ['depth_sph_corr-' basename '.mat']) );  %��example/sample_training_data�ļ����е�����depth_sph_.mat�ļ�����depthFile
    foo = load( fullfile(trainFilesDir, depthFile(1).name) );  %����ÿ��depth_sph_.mat�ļ�
    %depth_sph_.mat�ļ�����Position3DGrid��Position3DGrid��СΪ55*305*4������(:,:,4)�����
    depth = foo.Position3DGrid(:,:,4); %Load only depth from laser data  %���һά�����
    createData(dataDirName, img, depth, [], false); %false => verbose off
end
fprintf('done. [%6.02fs]\n', toc(prepTrainTime));

%% Create test data for example 1 image (unless it already exists)
img = im2double(imread(fullfile(EXAMPLES_DIR,'demo_data','img-op57-p-016t000.jpg')));  %��example/demo_data�ļ����еĲ���ͼƬ��.jpg)
if( ~exist(fullfile(project.path.data,'demo','001'), 'dir') ) %����data�ļ����е�demo�ļ��м������ļ�
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
