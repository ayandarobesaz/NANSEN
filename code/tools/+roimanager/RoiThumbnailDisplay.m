classdef RoiThumbnailDisplay < handle & roimanager.roiDisplay
%RoiThumbnailDisplay Widget for displaying a roi thumbnail image
%
%   This widget is created in a container (figure, panel, tab) and is
%   listening to changes on a RoiGroup. If a new roi is selected on the
%   RoiGroup, the display will update and show a thumbnail image of the
%   selected roi. Also, if the roi is modified, the image will update.
%
%   An imagestack can be added to The ImageStack property. If an image is
%   unavailable from a roi object, a new image will be created using the
%   imagestack.

    properties
        Dashboard   % Handle for dashboard where thumbnail display is present
        Parent      % Parent container (typically a uipanel)
    end
    
    properties
        ColorMap    % Todo
        LineColor   % Todo
    end
    
    properties
        ImageStack  % Handle of an ImageStack object. Necessary for creating roi images.
    end
    
    properties (Access = private)
        hAxes       % Handle for axes to show image in
        hText       % Handle for text which displays message
        hRoiImage   % Handle for image 
        hRoiOutline % Handle for line to show roi outline
    end 
    
    properties (Access = private)
        ShowRoiImageUpdateErrorMessage = false; % Flag for popup dialog.
    end
    
    methods % Constructor
        
        function obj = RoiThumbnailDisplay(hParent, roiGroup)
        %RoiThumbnailDisplay Create a RoiThumbnailDisplay object.
        %
        %   displayObj = RoiThumbnailDisplay(hParent, roiGroup) creates a
        %   thumbnail display object in the container specified by hParent.
        %   
        
            obj@roimanager.roiDisplay(roiGroup)
            
            obj.Parent = hParent;
            obj.createImageDisplay()

        end
        
    end
    
    methods (Access = private)
        
        function createImageDisplay(obj)
        %createImageDisplay Create axes for image display    
            
            % Create axes.
            obj.hAxes = axes('Parent', obj.Parent);
            obj.hAxes.Position = [0.05, 0.05, 0.9, 0.9];
            obj.hAxes.XTick = []; 
            obj.hAxes.YTick = [];
            obj.hAxes.Tag = 'Roi Thumbnail Display';
            obj.hAxes.Color = obj.Parent.BackgroundColor;
            obj.hAxes.Visible = 'off';
            
        end
        
        function plotRoiImageNotAvailableText(obj)
            
            obj.hText = text(obj.hAxes, 'Units', 'normalized');
            obj.hText.Position(1:2) = [0.5, 0.5];
            obj.hText.String = 'Roi image not available';
            obj.hText.Color = ones(1,3)*0.4;
            obj.hText.HorizontalAlignment = 'center';
            obj.hText.FontSize = 12;
            
        end
        
        function updateImageText(obj, str)
            if isempty(obj.hText) || ~isvalid(obj.hText)
                obj.plotRoiImageNotAvailableText()
            end
            obj.hText.String = str;
           
        end
        
        function updateImageDisplay(obj, roiObj)
            
            im = roiObj.enhancedImage;
            
            if all(im(:) == 0 )
                im = obj.createRoiImage(roiObj);
                obj.updateImageText('Image not available')
                if isempty(im); return; end
            end
            
            roiObj.enhancedImage = im;
            
            usFactor = 4; % Upsampling factor
            im = imresize(im, usFactor);
            
            if isempty(obj.hRoiImage) % First time initialization. Create image object
                obj.hRoiImage = imshow(im, [0, 255], 'Parent', obj.hAxes, 'InitialMagnification', 'fit');
%                 set(obj.himageCurrentRoi, 'ButtonDownFcn', @obj.mousePress)
               
                if ~ishold(obj.hAxes)  
                    hold(obj.hAxes, 'on') 
                end
            else
                set(obj.hRoiImage, 'cdata', im);
            end
            
            ul = roiObj.getUpperLeftCorner();
            roiBoundary = fliplr(roiObj.boundary{1});
            roiBoundary = (roiBoundary - ul + [1,1]) * usFactor;
            
            if isempty(obj.hRoiOutline)
                obj.hRoiOutline = plot(obj.hAxes, roiBoundary(:,1), roiBoundary(:,2), ...
                    'LineStyle', '-', 'Marker', 'None', 'LineWidth', 2 );
                % set(obj.hRoiOutline,  'Color', ones(1,3)*0.9 )
            else
                set(obj.hRoiOutline, 'XData', roiBoundary(:,1), 'YData', roiBoundary(:,2))
            end
            
            imSize = size(im);
            
            % To avoid erroring
            clims = [min(im(:)), max(im(:))];
            if clims(2) <= clims(1)
                clims(2) = clims(1) + 1;
            end
            
            
            set(obj.hAxes, 'XLim', [1,imSize(2)]+0.5, ...
                           'YLim', [1,imSize(1)]+0.5, ...
                           'CLim', clims );
            
            obj.updateImageText('')
            
        end
        
        function resetImageDisplay(obj)
            set(obj.hRoiOutline, 'XData', nan, 'YData', nan)
            set(obj.hRoiImage, 'cdata', [])
        end
        
        function im = createRoiImage(obj, roiObj)
        %createRoiImage Create a roi image from an ImageStack
            
            im = []; 
            if isempty(obj.ImageStack); return; end
                
            imArray = obj.ImageStack.getFrameSet('cache');
            
            if size(imArray, 3) < 100
                if obj.ShowRoiImageUpdateErrorMessage
                    obj.plotRoiImageNotAvailableText()
                    obj.Dashboard.displayMessage('Can not update roi image because there are not enough image frames in memory')
                    obj.ShowRoiImageUpdateErrorMessage = false;
                end
                im = [];
                return
            end
            
            f = nansen.twophoton.roisignals.extractF(imArray, roiObj);
            dff = nansen.twophoton.roisignals.computeDff(f, 'dffFcn', 'dffRoiMinusDffNpil');
            im = roimanager.autosegment.extractRoiImages(imArray, roiObj, dff'); 
        end
        
    end
    
    methods (Access = protected) % Inherited from roimanager.roiDisplay
        
        function onRoiGroupChanged(obj, evtData)
        %onRoiGroupChanged Callback for RoiGroupChanged event.
        %
        %   If a roi is modified, the image should be updated.
                    
            % Take action for this EventType
            switch lower(evtData.eventType)

                case {'modify', 'reshape'}
                    
                    if isempty(evtData.roiIndices)
                        return
                    end
                    
                    roiIdx = evtData.roiIndices(end);
                    % Update image if the displayed roi was modified
                    if isequal(roiIdx, obj.VisibleRois)
                        roi = obj.RoiGroup.roiArray(roiIdx);
                        obj.updateImageDisplay(roi)
                    end
                    
                otherwise
                    % Do nothing...
            end
            
        end
        
        function onRoiSelectionChanged(obj, evtData)
        %onRoiSelectionChanged Callback for RoiSelectionChanged event
        %
        %   Update the image display with an image of the selected roi
        
            if isempty(evtData.NewIndices)
                obj.resetImageDisplay()
                obj.updateImageText('No roi selected')
                obj.VisibleRois = [];
            else
                roiIdx = evtData.NewIndices(end);
                roi = obj.RoiGroup.roiArray(roiIdx);
                obj.updateImageDisplay(roi)
                obj.VisibleRois = roiIdx;
            end
            
        end
        
        function onRoiClassificationChanged(obj, evtData)
            % Do nothing
        end
        
    end
    
    methods % Implement abstract methods from
        function addRois(~)
            % This class can not add rois
        end
        
        function removeRois(obj)
            % This class can not remove rois
        end
    end
    
    
end