function o = efrosLeung(S, W, P)
	% An implementation of the Efros & Leung Texture Synthesis algorithm
	% S a sample image to derive the texture from (it's name, not the
	% loaded image)
	% W is how large a window should be used for fitting the texture,
	% larger windows takes more time, but produces better synthesis, since 
	% the algorithm will try to grow the base texture into a new larger texture/image
	% and the larger window will try to make a larger chunk of the image match
	% the base texture
    % P is the ammount of padding to use, eg if 0, the new texture is the 
    % same size as the old, if the padding is 1000, then 1000 pixels is
    % padded on all sides, making it 2000 pixels wider and longer, like
    % larger window sizes, larger ammounts of padding can also drastically
    % slow down the application (a large window and padding of 1000 can
    % easilly take hours, since the application is not GPU enabled
    input = S;
    if isstring(S)
        S= char(S);
    end
    if ischar(S)
        input = imread(S);
    end
    imshow(input)
	tic
	o = GrowImage(input, W, P);
	toc
    
    
    if(ischar(S))
        imwrite(o,strcat(S, 'larger.png'));
    end
    imshow(o)
end

function o = SSD(S, T, M)
	% Calculate the sum of the square difference, between S & T,
	% ignoring the indices marked in M.
	%
	% SSD(x,y) = sum i=-n:n, j=-n:n (S(x+i,y+j)-T(i,j))^2 *M(i,j)
	% this reduces to
	% SSD = ssq + ts + tsq, where
	% ssq(x,y) = sum i =-n:n,j=-n:n S(x+i,y+j)^2M(i,j)
	% tsq sum i=-n:n, j=-n:n T(i,j)^2 M(i,j) 
	% ts = sum i = -n:n,j = -n:n -2T(i,j)J(x+i,y+j)M(i,j)
	M = double(M);
	ssq = imfilter(S.^2, M);
	maskedT = T.*M;
	tSum = sum(maskedT(:).^2);
	ts = -2*imfilter(S,maskedT);
	o = tSum + ts + ssq;
end

function o = get(A, x, y)
	% simple helper function, get A(x,y), or -1 is x,y is out of bounds of A
	[n, m] = size(A);
	if( x < 1 || x > n || y < 1 || y > m)
		o = -1;
	else
		o = A(x,y);
	end
end

function [row,col] = findMatches(S,T,M)
	
	ssd = SSD(S,T,M);
	TotWeight = sum(M(:));
	ssd = ssd/TotWeight;
	filt = min(ssd(:)) * 1 + 0.1;
	[row, col] = find(ssd <= filt);
end

function o = seedImage(S, P)
	% S: The sample image
    % P: a specified ammount of padding
	% Take a sample section of the texture sample (S)
	% and put it in the image to grow (o)
	% Pad the image by P pixels, set new values to 
	% -1, so we know as long as the image has a -1, 
	% the texture hasn't been entirely synthesized.
	[n, m] = size(S);
	if (mod(n,2) ==0)
	   n = n + 1;
	end
	if(mod(m,2) == 0)
		m = m + 1;
	end
	nCen = (n - 1)/2 + 1;
	mCen = (m - 1)/2 + 1;
	o = ones(n,m);
	o=o*-1;
	[vec, y] = datasample(S,1);
	[~, x] = datasample(vec,1);
	if(y < 2)
		y = 2;
	end
	if( y > n -1)
		y = n - 1; 
	end
	if(x < 2)
		x = 2;
	end
	if( x > m -1)
		x = m - 1; 
	end

	for i=-1:1
		for j = -1:1
			o(nCen+i,mCen+j) = get(S,y+i,x+j);
		end
	end
	o = padarray(o,[P,P],-1);
end

function o = GrowImage(S, W, P)
	%% S the sample image to grow
	%% W the window size to fit the texture with
	%% P the ammount of padding to add to the seed image
	[~,~,z] = size(S);
	if(z == 3)
		%% if the image is in color, z =3 channels,
		%% combine the channels into one number to fit
		%% them together when solving
		S = uint32(S);
		S = S(:, :, 1).*2^(16) + S(:, :, 2).*2^8 + S(:, :, 3);
	end
	% the seeded image, a larger image than the sample, with a chunk 
	% of the sample image embedded in it
	o = seedImage(S,P); 
	o = double(o);
	S = double(S);
	% so long as the image contains -1's keep looping and updating values
	% trying to fit to the original sample.
	while(min(o(:)) == -1)
		[row, col] = getUnfilledNeighbors(o);% pixels needing updating
		pixlist = [row col];
		[n,~] = size(pixlist);
		for x= 1:n
			pix = pixlist(x,:);
			T = getNeighborhoodWindow(o, pix, W);
			M = T~=-1;
			[row, col] = findMatches(S,T,M);
			matches = [row col];
			[xsiz,~] = size(matches);
			if(xsiz > 1)
				ij = datasample(matches, 1);
			else 
				ij = matches;
			end
			o(pix(1), pix(2)) = S(ij(1),ij(2));
		end
	end
	
	if(z == 3)
		%% if the image had 3 channels extract the channels
		%% from the result and concatenat them into an image
		o = uint32(o);
		B = bitshift(o, -16);
		G = bitshift(bitshift(o,16),-24);
		R = bitshift(bitshift(o,24),-24);
		o = cat(3,B,G,R);
	end
	o = uint8(o);
end

function [row, col] = getUnfilledNeighbors(I)
	%% get the unfilled pixels from the image 'I'
	%% sorted by the number of neighbors they have
	%% the pixels with the most neighbors filled
	%% will be the ones that can be fitted the best.
	[o, ~] = imgradient(I < 0);
	o = o.*I;
	o = o < 0;
	cnt = sum(o(:));
	unfilled = o == 1;
	% find point weights (number of neighbors)
	F = [1,1,1;1,0,1;1,1,1];
	N = imfilter(double(I~=-1), F);
	unfilcnt = unfilled.*N;
	[row, col]= find(o~=0);
	o = [row,col];
	w = zeros(cnt,1);
	for x  = 1:cnt
		ij = o(x, :);
		w(x) = unfilcnt(ij(1), ij(2)); 
	end
	o = [row col w];
	o(:,3)=o(:,3)*-1; % max at top so reverse weights to reverse order
	o = sortrows(o, 3);
	row = o(:, 1);
	col = o(:, 2);
end

function o = getNeighborhoodWindow(I, pix, siz)
	% get a window of size 'siz' centered around the pixel 'pix'
	% in the image 'I'
	n = (siz - 1)/2;
	o = zeros(siz);
	N = n + 1;
	for i = -n:n
		for j = -n:n
			o(i+N,j+N) = get(I,pix(1)-i, pix(2)-j);
		end
	end
end