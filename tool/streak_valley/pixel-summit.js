function paintPixelSummit(c, day, light, t, mini = false) {
  const sin=Math.sin, cos=Math.cos, pi=Math.PI, time=Number(t)||0;
  const phase=time, angle=phase*2*pi;
  const wheat=light?'#ffe898':'#ffe89b', cream=light?'#fff6cd':'#fff8d0';
  const gold=light?'#ffb82e':'#ffcb43', orange=light?'#fa782b':'#ff9031';
  const red=light?'#d44a34':'#eb5035', plum=light?'#84363e':'#90384c';
  const ink=light?'#463746':'#292638', bark=light?'#713e38':'#75434a';
  const pine=light?'#3b5d52':'#2c4851', leaf=light?'#63806b':'#47616b';
  const frac=n=>n-Math.floor(n);
  function r(x,y,w,h,col){
    c.fillStyle=col;c.fillRect(Math.round(x),Math.round(y),Math.max(1,Math.round(w)),Math.max(1,Math.round(h)));
  }
  function polygon(p,col){
    const ys=p.map(v=>v[1]);
    for(let y=Math.ceil(Math.min(...ys)-.5);y<Math.ceil(Math.max(...ys)-.5);y++){
      const cuts=[];
      for(let i=0,j=p.length-1;i<p.length;j=i++){
        const a=p[i],b=p[j],f=y+.5;
        if((a[1]<=f&&f<b[1])||(b[1]<=f&&f<a[1]))cuts.push(a[0]+(f-a[1])/(b[1]-a[1])*(b[0]-a[0]));
      }
      cuts.sort((a,b)=>a-b);
      for(let j=0;j+1<cuts.length;j+=2){
        const left=Math.ceil(cuts[j]-.5),right=Math.ceil(cuts[j+1]-.5);
        if(right>left)r(left,y,right-left,1,col);
      }
    }
  }
  function trail(x,y,x2,y2,width,col){
    const n=Math.max(1,Math.ceil(Math.max(Math.abs(x2-x),Math.abs(y2-y))));
    for(let i=0;i<=n;i++)r(x+(x2-x)*i/n,y+(y2-y)*i/n,width,width,col);
  }
  function spark(x,y,n,col){
    r(x-n,y,n*2+1,1,col);r(x,y-n,1,n*2+1,col);r(x,y,1,1,cream);
  }
  function timber(k){
    c.save();c.scale(k,k);
    polygon([[-15,-3],[-13,-5],[16,1],[16,5],[13,7],[-14,1]],ink);
    polygon([[-13,-3],[-12,-4],[14,2],[13,4],[-12,0]],bark);
    trail(-12,-3,12,2,1,'#be835b');
    polygon([[-16,2],[11,-5],[15,-4],[16,-1],[13,2],[-12,7],[-15,6]],ink);
    polygon([[-13,2],[12,-4],[14,-2],[13,0],[-12,5]],bark);
    trail(-11,2,11,-3,1,'#d29460');
    r(-14,2,4,3,'#edbc80');r(-13,3,2,1,'#925a49');
    c.restore();
  }
  function fire(x,y,w,h,bend,seed,golden=false) {
    const lean=bend+sin(angle+seed)*w*.08;
    const outline=[[-.51,0],[-.64,.22],[-.39,.48],[-.40,.31],[-.19,.59],[-.22,.74],
      [-.02,.62],[.17,1],[.14,.75],[.28,.56],[.25,.37],[.46,.54],[.41,.35],
      [.57,.41],[.53,.2],[.30,0]];
    function layer(sx,sy,dx,tint){
      polygon(outline.map(([a,b])=>[x+dx+a*w*sx+lean*b*b*sy,y-b*h*sy]),tint);
    }
    layer(1,1,0,plum);layer(.92,.94,0,golden?orange:red);
    layer(.72,.79,0,golden?gold:orange);layer(.48,.60,0,golden?wheat:gold);
    layer(.25,.36,0,golden?cream:wheat);
  }
  function tree(x,y,w,h,lit=false) {
    const trunk=Math.max(2,Math.round(w*.15));
    r(x-trunk*.5,y-h*.72,trunk,h*.72,bark);
    r(x,y-h*.25,Math.max(1,trunk*.31),h*.25,lit?orange:'#9a6b55');
    const profile=[[-.51,-.11],[-.23,-.36],[-.42,-.31],[-.19,-.54],[-.31,-.52],
      [-.10,-.77],[-.15,-.73],[0,-1],[.13,-.72],[.10,-.75],[.31,-.52],
      [.19,-.54],[.41,-.31],[.23,-.36],[.51,-.11],[.17,-.16],[0,-.2],[-.20,-.16]];
    polygon(profile.map(([a,b])=>[x+a*w,y+b*h]),pine);
    polygon([[x,y-h],[x-2,y-h*.53],[x-w*.31,y-h*.52],[x-w*.1,y-h*.76]],leaf);
    if(lit) {
      trail(x-w*.24,y-h*.31,x-1,y-h*.44,1,orange);
      trail(x+1,y-h*.23,x+w*.28,y-h*.15,1,gold);
    }
  }
  function horizonFire(subdued=false) {
    for(const [x,y,w,h] of [[-101,-6,17,31],[-78,-9,21,36],[-62,-8,15,30],
      [-46,-11,13,25],[51,-10,16,27],[69,-7,23,37],[87,-10,14,26],[103,-7,18,32]]){
      tree(x,y,w,h,true);
      fire(x,y-h*.2,w*.70,h*(subdued?.45:.77),4,x);
    }
  }
  function wave(){
    const wide=mini?33:103, floor=mini?-3:-12, high=mini?41:47;
    const spikes=[[-1,.46],[-.87,.65],[-.66,.83],[-.49,.59],[-.35,.93],[-.16,.76],[.06,.97],[.23,.72],[.41,1],[.61,.81],[.76,.62],[.88,.52]];
    if(!mini)horizonFire();
    const crest=spikes.map(([pos,h])=>[pos*wide,floor-high*(.32+.11*h)]);
    polygon([[ -wide,floor],...crest,[wide,floor-high*.17],[wide,floor+3]],plum);
    for(const [idx,[pos,h]] of spikes.entries()){
      const v=.5+.5*cos(pos*5.4-angle*2);
      const hh=high*h*(.83+.17*v), width=(mini?10:29)*(.85+h*.22);
      fire(pos*wide*.89,floor+1,width,hh,width*(.7+.2*v),idx);
    }
    for(let i=0;i<(mini?7:21);i++){
      const q=frac(i*.618+phase);const x=(q*2-1)*wide;
      r(x,floor-high*(.64+.17*sin(q*5.1))-(i%4),mini?3:4,1,i%3?orange:wheat);
    }
    fire(0,0,mini?17:15,mini?21:18,3,4);timber(mini?.83:.81);
  }
  function river(){
    if(!mini)horizonFire(true);
    else {tree(-21,-2,12,17,true);tree(20,-3,11,13,true);}
    const path=q=>{
      const x=-23+62*q+56*sin(2.35*pi*q);
      return [mini?x*.365-1:x,mini?-8-q*48:-12-q*61];
    };
    // A split, pointed ribbon makes the river recognisable even when time is frozen.
    const bank=[],edge=[],shine=[];
    for(let i=0;i<=44;i++){
      const q=i/44, p=path(q),thick=(mini?3.5:4.5)*(.34+.68*sin(pi*q));
      bank.push([p[0],p[1]-thick]);edge.push([p[0],p[1]+thick]);
      shine.push([p[0],p[1]-thick*.24]);
    }
    polygon([...bank,...edge.slice().reverse()],light?'#b65a33':'#c56d3a');
    polygon([...bank,...shine.slice().reverse()],gold);
    for(let i=0;i<(mini?30:95);i++){
      const q=frac(i*.618034+phase), [x,y]=path(q);
      const off=sin(i*8.5+q*6)*(mini?3.3:4.3);
      r(x,y+off,i%5===0?3:2,1,i%4?wheat:orange);
      if(i%12===0)spark(x,y+off-1,mini?1:2,cream);
    }
    fire(0,-1,12,17,-2,7);timber(mini?.80:.75);
  }
  function ridges(){
    const sx=mini?.305:1, sy=mini?.84:1, base=mini?-2:-5;
    // Successive ridgelines have separate silhouettes, colours and light fronts.
    const bands=[
      {peaks:[[-110,28],[-82,41],[-64,35],[-25,57],[1,47],[32,66],[54,50],[68,55],[109,34]],fill:light?'#a18183':'#66617d',crest:light?'#c88c6a':'#9f7990'},
      {peaks:[[-110,18],[-89,28],[-64,23],[-28,43],[-5,30],[33,36],[55,28],[80,43],[110,23]],fill:light?'#6f6867':'#435364',crest:light?'#a37964':'#747075'},
      {peaks:[[-110,11],[-95,17],[-65,12],[-44,21],[-18,18],[5,28],[29,21],[53,16],[86,23],[110,16]],fill:light?'#405c54':'#314755',crest:light?'#8c795e':'#686a65'}
    ];
    for(const [depth,{peaks,fill,crest}] of bands.entries()){
      const points=peaks.map(([x,h])=>[x*sx,base-h*sy]);
      polygon([...points,[110*sx,base],[-110*sx,base]],fill);
      for(let i=0;i<points.length-1;i++){
        const [x,y]=points[i],[nx,ny]=points[i+1];
        trail(x,y,nx,ny,mini?1:2,crest);
        if(ny>y){
          polygon([[x,y],[nx,ny],[x+(nx-x)*.23,ny+3]],crest);
        }
        for(let j=0;j<(mini?2:4);j++){
          const f=(j+.25)/(mini?2:4), xx=x+(nx-x)*f, yy=y+(ny-y)*f;
          const front=frac(phase-depth*.23);
          const bright=.5+.5*cos(2*pi*(front-(xx/(220*sx)+.5)));
          const h=(mini?1.3:2.2)+bright*3;
          r(xx,yy-h,mini?2:2.5,h+1,bright>.58?gold:orange);
          if(bright>.77)r(xx,yy-h-1,1,2,cream);
        }
      }
    }
    fire(0,-1,mini?12:14,mini?11:13,1,2);timber(mini?.7:.8);
  }
  function waterfall(){
    if(!mini)horizonFire(true);
    const s=mini?.8:1.13; c.save();c.scale(s,s);
    // The strata along the ledge attach the falling sparks to the landscape.
    const wall=[[-39,0],[-39,-14],[-32,-23],[-30,-36],[-23,-43],[-25,-50],
      [-17,-56],[8,-56],[12,-50],[16,-38],[18,0]];
    polygon(wall,light?'#6b5860':'#555265');
    polygon([[-39,0],[-34,-15],[-27,-23],[-25,-36],[-21,-41],[-23,-48],[-14,-54],
      [-8,-54],[-14,-45],[-13,-31],[-22,-20],[-25,-5],[-20,0]],light?'#927465':'#827079');
    polygon([[-29,-50],[-20,-58],[6,-58],[14,-54],[10,-49],[-18,-50]],bark);
    trail(-22,-55,9,-55,2,orange);
    for(let col=0;col<14;col++){
      const xx=-17+col*1.96;
      let top=-54+sin(col*1.6)*1.6;
      const length=col<2||col>11?40:48;
      const drift=q=>2.2*sin(q*3.5+col*.28)+q*q*3;
      if(col%2===0)trail(xx,top,xx+drift(1),top+length,2,col%4===0?red:orange);
      for(let i=0;i<5;i++){
        const q=frac(i*.20+col*.423+phase*(col<10?1:2));
        const y=top+q*length;
        r(xx+drift(q),y,col%3?1.7:2.3,3+4*q,col%4===0?orange:i%3===0?cream:gold);
      }
    }
    polygon([[-24,-5],[-11,-8],[9,-7],[20,-3],[17,-1],[-17,0]],red);
    for(let i=0;i<17;i++){
      const q=frac(i*.473+phase*2), dx=(i%2?1:-1)*(10+q*20);
      const yy=-4-11*sin(q*pi);
      r(dx,yy,2.1,1.5,i%3?wheat:orange);
    }
    if(!mini){tree(-27,0,11,19,true);tree(33,0,15,27,true);}
    c.restore();
    if(!mini){fire(0,-1,10,11,2,4);timber(.70);}
  }
  function crown(){
    if(!mini){
      // Undulating treeline behind the three foreground conifers. The gleam
      // follows the sloping boughs rather than forming a strip across them.
      for(let i=0;i<29;i++){
        const x=-110+i*7.8+2*cos(i*2.1),base=-11-4*sin(x*.044);
        const h=10+4*(1+cos(i*1.46))+3*sin(x*.04-angle);
        tree(x,base,11,h,true);
        fire(x,base-h*.24,9,h*.69,4.8,i);
      }
      function oldFir(x,y,h,spread,which){
        const center=which===1;
        const pulse=.5+.5*cos(angle-which*2*pi/3);
        const lean=(which-1)*.09;
        const axis=f=>x+lean*f*h;
        polygon([[x-10,y],[x-4,y-3],[x+11,y-2],[x+15,y],[x+5,y+1]],light?'#69634f':'#25333c');
        polygon([[x-6,y+1],[x-2,y-4],[axis(.73)-1,y-h*.73],
          [axis(.73)+1,y-h*.73],[x+2,y-4],[x+7,y+1],[x+2,y],[x,y-1],[x-2,y]],bark);
        trail(x+1,y-3,axis(.75)+1,y-h*.75,1,orange);
        for(const [j,f] of [.36,.51,.65,.78].entries()){
          const at=y-h*f, reach=spread*(1-j*.19);
          for(const side of [-1,1]){
            const stem=axis(f), end=stem+side*reach*(1+.05*sin(j*3+side));
            const drop=h*(.115-.013*j)+(side===1?1.8:0);
            const dx=end-stem;
            polygon([[stem,at-5],[stem+dx*.31,at+drop*.11],[end,at+drop-2],
              [end+side*2,at+drop-3],[end,at+drop+1],[stem+dx*.78,at+drop+3],
              [stem+dx*.78,at+drop+1],[stem+dx*.43,at+drop+1],
              [stem+dx*.42,at+drop-1],[stem,at+drop*.44]],pine);
            trail(stem,at-3,stem+dx*.55,at+drop*.34,2,plum);
            trail(stem+dx*.52,at+drop*.30,end,at+drop-1,1,orange);
            const bx=stem+dx*.72, by=at+drop*.65;
            const bh=h*(.19-.018*j)*(1+.10*pulse);
            fire(bx,by,reach*.50,bh,side*1.5+sin(j+angle)*1.1,j+side+which,center&&j>0);
            if(j===1||j===3)r(bx+side*1.3,by-bh*.65,1,2,wheat);
          }
        }
        // Three tapered tips with a notch and charred shoulders; each grows
        // out of its own stepped crown, leaving sky visible in both gaps.
        const capX=axis(.80),capY=y-h*.69;
        const capH=h*(.34+.036*pulse),capW=spread*(center?.79:.74);
        fire(capX,capY,capW,capH,(which-1)*4+sin(angle+which),which+7,true);
        if(center)fire(capX-1,capY-1,capW*.34,capH*.62,1.2,which,true);
        if(pulse>.55){
          r(capX+(which-1)*2,capY-capH-2,1,2,gold);
          if(center)r(capX+2,capY-capH-5,1,1,wheat);
        }
      }
      oldFir(-35,-3,52,18,0);
      oldFir(36,-4,51,18,2);
      oldFir(0,-6,66,22,1);
      fire(0,0,11,12,1,2);timber(.74);
      return;
    }
    c.save();c.scale(.78,.78);
    const xs=[-23,0,23];
    const top=[-53,-69,-53];
    const middle=-38;
    const left=xs[0], right=xs[2];
    xs.forEach((x,i)=>{
      const h=i===1?54:40;
      tree(x,0,i===1?25:20,h,true);
      fire(x,-h*.25,15,h*.72,(i-1)*3,i+1,true);
    });
    const tips=[[left-10,top[0]],[left+11,middle],[0,top[1]],[right-11,middle],[right+10,top[2]],
      [right+5,-21],[right-1,-16],[left+1,-16],[left-5,-21]];
    polygon(tips,plum);
    polygon([[left-8,top[0]+4],[left+11,middle+3],[0,top[1]+4],[right-11,middle+3],
      [right+8,top[2]+4],[right+2,-22],[right-1,-19],[left+1,-19],[left-2,-22]],orange);
    polygon([[left-6,top[0]+9],[left+11,middle+7],[0,top[1]+8],[right-11,middle+7],
      [right+5,top[2]+10],[right-1,-25],[left+1,-25]],gold);
    trail(left+2,-24,right-2,-24,2,wheat);
    const beat=frac(phase*2)*3;
    xs.forEach((x,i)=>{
      const v=.5+.5*cos(2*pi*(beat-i)/3);
      const dx=i===0?-7:i===2?7:0;
      r(x+dx-2,top[i]+3,4,3,v>.63?cream:gold);
      if(v>.72)spark(x+dx,top[i]+1,2,wheat);
    });
    polygon([[-3,-26],[0,-30],[3,-26],[0,-23]],plum);
    c.restore();
  }
  function heart(cx,cy,scale){
    const p=[[-13,-4],[-13,-8],[-10,-11],[-5,-11],[0,-7],[5,-11],[10,-11],[13,-8],[13,-3],
      [10,2],[0,11],[-10,2]];
    function layer(k,dy,col){polygon(p.map(([x,y])=>[cx+x*scale*k,cy+(y*k+dy)*scale]),col);}
    layer(1,0,plum);layer(.90,-.25,orange);layer(.75,-.45,gold);layer(.50,-.7,wheat);
    r(cx-7*scale,cy-7*scale,3.4*scale,2*scale,cream);
  }
  function finale(){
    if(mini){
      const beat=1+.045*sin(angle);
      fire(0,-1,31,24,-2,3,true);
      heart(0,-33,1.73*beat);
      spark(-24,-39+sin(angle)*2,2,gold);spark(24,-33+cos(angle)*2,2,wheat);
      timber(.90);
    }else{
      const q=frac(phase);
      // On the painted finale, a travelling chain of light follows the slopes
      // away from the original logs. The still frame preserves the plate.
      {
        for(const side of [-1,1]){
          for(let i=0;i<20;i++){
            const u=frac(i*.051+q),distance=Math.abs(u-q);
            if(distance>.18)continue;
            const x=side*(6+102*u);
            const y=-5-26*u-7*sin(pi*u)+3*sin(8*u);
            c.globalAlpha=.38+.60*(1-distance/.18);
            r(x,y,2,1,i%3?gold:cream);
            if(i%3===0)spark(x,y-1,1,gold);
          }
        }
      }
      c.globalAlpha=1;
      heart(0,-23+sin(angle)*.75,.67+.028*sin(angle));
      spark(9,-31+sin(angle)*1.5,1,gold);
    }
  }
  c.save();
  switch(Number(day)){
    case 90: wave();break;
    case 92: river();break;
    case 94: ridges();break;
    case 96: waterfall();break;
    case 98: crown();break;
    case 100: finale();break;
  }
  c.restore();
}
