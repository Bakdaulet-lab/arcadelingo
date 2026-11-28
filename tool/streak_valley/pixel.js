function paintPixel(ctx, day, light, t, miniature = false, comparison = false) {
  const c = ctx;
  const d = Number(day);
  const clock = Math.max(0, Number(t) || 0);

  const sin = Math.sin;
  const phase=clock, angle=phase*2*Math.PI;
  if (d < 7 || d >= 35) {
    const painter = d < 7 ? paintPixelDawn : d < 90 ? paintPixelGrove : paintPixelSummit;
    c.save();
    c.scale(3,3);
    c.imageSmoothingEnabled = false;
    if (miniature) {
      c.translate(120,85);
      const scale = d < 7 ? 1.83 : 1.30;
      c.scale(scale,scale);
    } else c.translate(120,84);
    painter(c,d,light,clock,miniature);
    c.restore();
    return;
  }
  const P = light ? {
    ink:'#3e2936', bark:'#704238', grain:'#ba7850', cut:'#efc18a', ring:'#9a5c47',
    smoke:'#665e72', smokeHi:'#8e8192', tree:'#385a57', leaf:'#56796b',
    shadow:'#645153', ground:'#a17c63', moss:'#838b63', stone:'#827477', rim:'#d2a479',
    maroon:'#983551', red:'#d64435', orange:'#fc752e', gold:'#ffb72f', hot:'#ffdf79', core:'#fff0be'
  } : {
    ink:'#261f37', bark:'#70464b', grain:'#be7852', cut:'#ffc88b', ring:'#a56552',
    smoke:'#b2adc8', smokeHi:'#d2cbdc', tree:'#24384c', leaf:'#385868',
    shadow:'#1d2136', ground:'#685051', moss:'#626652', stone:'#615d68', rim:'#bd8d70',
    maroon:'#99344c', red:'#ec533b', orange:'#ff8731', gold:'#ffc745', hot:'#ffe790', core:'#fff3ca'
  };
  const rect = (x,y,w,h,color) => {
    c.fillStyle = color;
    c.fillRect(Math.round(x),Math.round(y),Math.max(1,Math.round(w)),Math.max(1,Math.round(h)));
  };
  // Scan conversion keeps diagonal faces and foliage on the pixel grid.
  function shape(points,color) {
    const ys=points.map(p=>p[1]);
    for (let y=Math.ceil(Math.min(...ys)); y<Math.ceil(Math.max(...ys)); y++) {
      let hits=[];
      for (let i=0,j=points.length-1;i<points.length;j=i++) {
        const a=points[j],b=points[i],yc=y+.5;
        if ((a[1]<=yc && yc<b[1]) || (b[1]<=yc && yc<a[1]))
          hits.push(a[0]+(yc-a[1])*(b[0]-a[0])/(b[1]-a[1]));
      }
      hits.sort((a,b)=>a-b);
      for(let i=0;i+1<hits.length;i+=2) {
        const left=Math.ceil(hits[i]-.5),right=Math.ceil(hits[i+1]-.5);
        if(right>left)rect(left,y,right-left,1,color);
      }
    }
  }
  function line(x0,y0,x1,y1,color,width=1) {
    x0=Math.round(x0);y0=Math.round(y0);x1=Math.round(x1);y1=Math.round(y1);
    const dx=Math.abs(x1-x0), dy=-Math.abs(y1-y0);
    const sx=x0<x1?1:-1,sy=y0<y1?1:-1;
    let e=dx+dy;
    for (;;) {
      rect(x0,y0,width,width,color);
      if(x0===x1 && y0===y1)break;
      const e2=2*e;
      if(e2>=dy){e+=dy;x0+=sx;}
      if(e2<=dx){e+=dx;y0+=sy;}
    }
  }
  function diamond(x,y,n,color) {
    for(let j=1-n;j<n;j++)rect(x-n+1+Math.abs(j),y+j,2*(n-Math.abs(j))-1,1,color);
  }
  function wood() {
    shape([[-15,0],[-14,-3],[-12,-4],[13,2],[15,4],[14,7],[11,7],[-14,2]],P.ink);
    shape([[-13,-3],[-11,-3],[13,3],[12,5],[-13,1]],P.bark);
    line(-11,-2,11,3,P.grain);
    shape([[-14,3],[-12,1],[12,-4],[14,-4],[16,-2],[15,1],[12,2],[-11,7],[-14,6]],P.ink);
    shape([[-11,2],[12,-3],[14,-3],[14,0],[-9,5]],P.bark);
    line(-8,2,12,-2,P.grain);
    rect(-13,3,4,3,P.cut);rect(-12,2,2,1,P.cut);
    rect(-12,3,2,2,P.ring);rect(-12,3,1,1,P.cut);
    rect(12,3,2,2,P.ring);
    if(d>=10){rect(-4,1,3,1,P.orange);rect(5,-1,2,1,P.gold);}
  }
  function coals(x,y) {
    shape([[x-13,y+2],[x-10,y-1],[x+7,y-2],[x+13,y],[x+11,y+3],[x-8,y+4]],P.maroon);
    for(let i=0;i<13;i++)rect(x-11+i*1.8,y+(i%3)-.5,1+(i%2),1,i%4===0?P.gold:P.orange);
  }
  // Fitted brushstrokes with a dark outer pixel and progressively hotter faces.
  // The root stays fixed while the tip follows the specified bend.
  function tongue(x,y,width,height,bend,phase=0) {
    function layer(scale,stretch,offset,tone) {
      const left=[], right=[];
      for(let n=0;n<=14;n++){
        const k=n/14, level=k*stretch;
        const cx=x+bend*(level*level)+offset+sin(level*3.6+phase)*width*.08*level;
        const envelope=(.72+.37*sin(k*4.15))*Math.pow(1-k,.78);
        const half=width*.5*scale*envelope;
        left.push([cx-half,y-level*height]);right.push([cx+half,y-level*height]);
      }
      shape([...left,...right.reverse()],tone);
    }
    layer(1,1,0,P.maroon);layer(.84,.94,0,P.red);
    layer(.61,.8,-.3,P.orange);layer(.40,.63,.15,P.gold);layer(.18,.36,.3,P.hot);
  }
  function emberShelf() {
    const hotSpot=-28+((phase+.37)%1)*56;
    c.save();
    c.globalAlpha=.43;
    rect(-23,3,46,2,P.red);rect(-17,5,33,1,P.orange);
    c.restore();
    shape([[-24,-2],[-20,-7],[-14,-8],[-8,-11],[-3,-10],[2,-12],[9,-11],[13,-9],
      [19,-9],[24,-5],[22,0],[15,2],[-15,2]],P.ink);
    shape([[-23,-2],[-20,-5],[-13,-7],[-8,-10],[-3,-9],[2,-11],[9,-10],[13,-8],
      [18,-8],[23,-5],[21,-1],[15,1],[-14,1]],P.maroon);
    const stones=[
      [-22,-3,8,4],[-16,-6,9,5],[-9,-8,8,6],[-1,-9,7,7],[6,-8,8,7],[13,-6,10,5],
      [-17,-2,8,4],[-9,-2,10,4],[1,-2,10,4],[12,-2,8,4]
    ];
    for(const [x,y,w,h] of stones){
      const bulb=Math.max(0,1-Math.abs(x+w/2-hotSpot)/13);
      shape([[x,y],[x+2,y-h*.6],[x+w-2,y-h*.75],[x+w,y-h*.28],[x+w-1,y+1],[x+2,y+1]],P.maroon);
      shape([[x+1,y-1],[x+3,y-h*.58],[x+w-2,y-h*.62],[x+w-1,y-1],[x+w-3,y],[x+3,y]],P.orange);
      line(x+2,y-h*.47,x+w-3,y-h*.61,P.gold);
      if(bulb>0){c.globalAlpha=bulb;line(x+1,y-1,x+w-3,y-h*.56,P.core,2);c.globalAlpha=1;}
    }
    for(const [x,y] of [[-13,-7],[-3,-10],[7,-9],[16,-6]]){
      const hot=Math.max(0,1-Math.abs(x-hotSpot)/10);
      line(x,y,x-1,y+2,P.ink);line(x-1,y+2,x+1,y+3,P.ink);
      if(hot>0){c.globalAlpha=hot;line(x,y+1,x+1,y+3,P.hot);c.globalAlpha=1;}
    }
    tongue(-5,-10,4,3.2+sin(angle)*.6,1);
    tongue(11,-8,3,2.6-sin(angle)*.6,-1);
  }
  function twinFire() {
    const wave=sin(angle);
    tongue(0,-2,17,11,wave*.7);
    tongue(-3,-5,10,17-wave*1.3,-7-wave*1.3);
    tongue(3,-5,11,21+wave*1.3,8-wave*.8);
    // One burst separates into five diverging, ballistic streaks.
    for(let i=-2;i<=2;i++){
      const u=((phase*2+.5135-Math.abs(i)*.0378+1)%1)/.665;
      if(u>=1) continue;
      const x=i*(3+10*u),y=-10-(35-Math.abs(i)*2)*u+7*u*u;
      c.globalAlpha=Math.min(1,u*5,(1-u)*7);
      line(x-i*1.2,y+3,x,y,i%2?P.gold:P.hot,2);
      if(i===0)diamond(x,y,2,P.core);
    }
    c.globalAlpha=1;
  }
  function spreadingFire() {
    const travel=angle;
    for(const [x,width,height,bend] of [[-16,12,12,-7],[-8,14,19,-4],[11,14,17,5],[17,11,11,7],[0,17,27,-1]]){
      const crest=.5+.5*Math.cos(travel-x*.135);
      tongue(x,-1,width,height*(.65+.35*crest),bend+3.3*sin(travel-x*.135),x*.17);
    }
    for(const x of [-19,-9,2,13]){
      const glow=.5+.5*Math.cos(travel-x*.135);
      c.globalAlpha=.3+.6*glow;rect(x,1,5,1,P.hot);
    }
    c.globalAlpha=1;
  }
  function braidedFire(){
    const height=41+sin(angle)*1.5;
    const span=6;
    // Two distinct ribbons of light cross twice along the tapered shaft.
    // Their edges travel upwards with the same phase as the inner highlights.
    for(let j=0;j<Math.ceil(height);j++){
      const u=j/height,twist=u*8.2-angle;
      const axis=2.7*sin(u*4-angle)*u;
      const envelope=Math.pow(1-u,.62);
      const spread=span*sin(twist)*envelope;
      const half=5.8*(1-u*.67)*Math.min(1,(1-u)*5);
      const a=axis+spread,b=axis-spread;
      const warm=(cx,front,bright)=>{
        rect(cx-half,-j-3,2*half+1,1,front?P.red:P.maroon);
        if(half>1)rect(cx-half+1,-j-3,Math.max(1,half*1.5),1,bright?P.gold:P.orange);
        if(front&&bright&&half>=2)rect(cx-half+2,-j-3,Math.max(1,half*.52),1,P.hot);
      };
      const forward=Math.cos(twist)>0;
      if(forward){warm(b,false,false);warm(a,true,true);}
      else{warm(a,false,true);warm(b,true,false);}
    }
  }
  function nearbyPine(x,y,h,spread) {
    rect(x-1,y-h,2,h,P.bark);
    for(let row=0;row<3;row++) {
      const width=spread*(row+1)/3;
      const top=y-h+row*h*.19;
      shape([[x,top],[x+width,top+h*.42],[x+2,top+h*.39],[x-2,top+h*.43],[x-width,top+h*.42]],P.tree);
      line(x+1,top+2,x+width-1,top+h*.40,P.leaf);
    }
  }
  function turf() {
    shape([[97,88],[98,86],[108,84],[133,84],[144,86],[139,89],[108,90]],P.shadow);
    if(d<21)return;
    if(d<28){
      for(let x=86;x<=153;x+=4){
        const crest=.5+.5*Math.cos(angle-(x-120)*.135);
        c.globalAlpha=(.14+.30*crest)*Math.min(1,(x-84)/8,(156-x)/9);
        rect(x,88+Math.round(Math.abs(x-120)*.065),4,1,P.orange);
        if(crest>.5)rect(x+1,90,2,1,P.gold);
      }
      c.globalAlpha=1;
    }
    for(const [x,y,w] of [[94,85,5],[101,88,4],[138,87,4],[145,82,6],[110,91,3]]){
      shape([[x-w,y+1],[x-w+1,y-1],[x-1,y-2],[x+w-1,y-1],[x+w,y+1],[x+1,y+2]],P.stone);
      rect(x-1,y-2,w-1,1,P.rim);
    }
    for (const [x,y,s] of [[92,90,1],[146,89,1],[102,80,-1],[139,80,-1],[84,84,-1],[151,86,1]]){
      line(x,y,x-2*s,y-4,P.moss);line(x,y,x+3*s,y-3,P.moss);rect(x,y-3,1,2,P.rim);
    }
  }
  function centerFire() {
    if(d>=14)coals(0,1);
    if(d<10) {
      const lean=4.4*sin(angle+.45);
      tongue(0,-2,21,19+sin(angle),lean);
    } else if(d<14) emberShelf();
    else if(d<21) twinFire();
    else if(d<28) spreadingFire();
    else braidedFire();
    if(d>=21&&d<28) {
      shape([[-25,1],[-23,-3],[-17,-3],[21,-2],[24,0],[22,3],[-22,4]],P.ink);
      shape([[-22,-2],[-17,-2],[20,-1],[20,1],[-21,2]],P.bark);
      rect(-23,-1,3,3,P.cut);line(-18,0,18,0,P.grain);
      c.save();c.scale(1.22,1.1);wood();c.restore();
    } else wood();

  }
  c.save();c.scale(3,3);c.imageSmoothingEnabled=false;
  if(miniature){
    const size=d>=28?1.79:d>=21?1.90:d>=14?1.78:d>=10?1.98:2.45;
    c.translate(120,d>=28?85:d>=14?78:d>=10?61:69);c.scale(size,size);
    if(d===21){rect(-18,5,4,1,P.rim);rect(15,5,4,1,P.rim);}
    centerFire();
  } else {
    if(!comparison && d>=28){nearbyPine(72,80,32,10);nearbyPine(173,78,40,13);}
    turf();
    c.translate(120,84);centerFire();
  }
  c.restore();
}
