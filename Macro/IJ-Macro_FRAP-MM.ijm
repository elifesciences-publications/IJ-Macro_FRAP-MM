//----------------------------------------
var frames;
var time;
var nRois=0;
var roiAreas;

var colors=newArray("red", "green", "blue", "black", "cyan", "magenta", "orange", "pink", "yellow", "darkGray", "gray", "lightGray");

//----------------------------------------


getDimensions(width, height, channels, slices, frames);

buildTime();
preProcess();
getRoiAreas();
quantify();
correctForBkgd();
correctForBleach();
normalize();
graph();



//----------------------------------------
function buildTime(){
	frames=28;

	Dialog.create("FRAP: timing");
	Dialog.addNumber("Pre-bleach_duration_(sec)", 180);
	Dialog.addNumber("Pre-bleach_intervalle_(sec)", 30);
	Dialog.addNumber("1st_Post-bleach_duration_(sec)", 180);
	Dialog.addNumber("1st_Post-bleach_intervalle_(sec)", 30);
	Dialog.addNumber("2nd_Post-bleach_duration_(sec)", 4200);
	Dialog.addNumber("2nd_Post-bleach_intervalle_(sec)", 300);
	Dialog.show();
	
	preDur=Dialog.getNumber();
	preInt=Dialog.getNumber();
	postDur1=Dialog.getNumber();
	postInt1=Dialog.getNumber();
	postDur2=Dialog.getNumber();
	postInt2=Dialog.getNumber()

	nPre=floor(preDur/preInt)+1;
	nPost1=floor(postDur1/postInt1)+1;
	nPost2=floor(postDur2/postInt2)+1;

	nFrames=minOf(nPre+nPost1+nPost2, frames);

	time=newArray(nFrames);
	
	intervalle=preInt;
	time[0]=0;
	for(i=1; i<nFrames; i++){
		if(i>=nPre) intervalle=postInt1;
		if(i>=nPre+nPost1) intervalle=postInt2;
		time[i]=time[i-1]+intervalle;
	}
}



//----------------------------------------
function preProcess(){
	roiManager("Reset");
	
	run("Metamorph rgn file to RoiManager...");
	nRois=roiManager("Count");

	getRoi("reference fluorescence", "Ref_fluo");
	getRoi("background", "Background");

	enlargeRois();
	
	Stack.setFrame(1);
	run("StackReg ", "transformation=[Rigid Body]");
}

//----------------------------------------
function getRoi(msg, roiName){
	run("Select None");
	setTool("freehand");
	waitForUser("Select the region\nwhere the "+msg+" should be evaluated\nthen click on Ok");
	addAndRename(roiName);
}

//----------------------------------------
function enlargeRois(){
	Dialog.create("Enlarge Rois");
	Dialog.addNumber("Number of pixels, (0 for no modif.)", 2);
	Dialog.show();

	enlarge=Dialog.getNumber();

	if(enlarge!=0){
		for(i=0; i<roiManager("Count")-2; i++){
			roiManager("Select", i);
			run("Enlarge...", "enlarge="+enlarge);
			roiManager("Update");
		}
	}
}

//----------------------------------------
function getRoiAreas(){
	roiAreas=newArray(nRois+2);
	for(i=0; i<roiManager("Count"); i++){
		roiManager("Select", i);
		getStatistics(roiAreas[i], mean, min, max, std, histogram);
	}
}

//----------------------------------------
function addAndRename(name){
	roiManager("Add");
	roiManager("Select", roiManager("Count")-1);
	roiManager("Rename", name);
}

//----------------------------------------
function quantify(){
	run("Clear Results");
	
	for(t=1; t<=frames; t++){
		row=nResults;
		setResult("Time_(sec)", row, time[t-1]);
		
		for(i=0; i<roiManager("Count"); i++){
			roiManager("Select", i);
			Stack.setFrame(t);
			getStatistics(area, mean, min, max, std, histogram);
			
			column="Roi"+(i+1);
			if(i==nRois) column="Ref_fluo";
			if(i==nRois+1) column="Background";

			setResult(column, row, area*mean);
		}
	}
}

//----------------------------------------
function correctForBkgd(){
	//Removes the bkgd, taking surface into account
	bkgd=getColumn("Background");

	for(i=0; i<nRois; i++){
		roi=getColumn("Roi"+(i+1));
		for(j=0; j<nResults; j++){
			setResult("Roi"+(i+1)+"-bkgd-corr", j, roi[j]-bkgd[j]*roiAreas[i]/roiAreas[nRois+1]);
		}
	}

	ref=getColumn("Ref_fluo");
	for(j=0; j<nResults; j++) setResult("Ref_fluo-bkgd-corr", j, ref[j]-bkgd[j]*roiAreas[nRois]/roiAreas[nRois+1]);
}

//----------------------------------------
function correctForBleach(){
	//Divides by the reference fluorescence intensity
	ref=getColumn("Ref_fluo-bkgd-corr");
	
	for(i=0; i<nRois; i++){
		roi=getColumn("Roi"+(i+1)+"-bkgd-corr");
		for(j=0; j<nResults; j++){
			setResult("Roi"+(i+1)+"-bkgd_bleach-corr", j, roi[j]/ref[j]);
		}
	}
}

//----------------------------------------
function normalize(){
	for(i=0; i<nRois; i++){
		roi=getColumn("Roi"+(i+1)+"-bkgd_bleach-corr");
		for(j=0; j<nResults; j++){
			setResult("Roi"+(i+1)+"_corr_norm", j, roi[j]/roi[0]);
		}
	}
}

//----------------------------------------
function getColumn(colName){
	out=newArray(nResults);
	for(i=0; i<nResults; i++) out[i]=getResult(colName, i);
	return out;
}

//----------------------------------------
function graph(){
	Plot.create("FRAP", "Time (sec)", "Normalized fluorescence");
	Plot.setLimits(time[0], time[time.length-1], 0, 1.25);

	for(i=0; i<nRois; i++){
		yValues=getColumn("Roi"+(i+1)+"_corr_norm");
		Plot.add("line", time, yValues);
		Plot.setColor(colors[i]);
	}	

	Plot.show();
}

