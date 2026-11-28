function paintPixelGrove(c, day, light, t, mini = false) {
  const time = Number.isFinite(t) ? t : 0, tau = Math.PI * 2;
  const sin = Math.sin, cos = Math.cos;
  const phase=time, angle=phase*tau, wave=sin(angle);
  const ink = light ? '#422d39' : '#251f36';
  const shade = light ? '#694046' : '#574052';
  const bark = light ? '#835143' : '#82514b';
  const grain = light ? '#ba7652' : '#c37d5b';
  const birch = light ? '#e2ae76' : '#f2bd88';
  const leaf = light ? '#35574e' : '#344d56';
  const moss = light ? '#758564' : '#7e8d80';
  const ash = light ? '#973b4c' : '#902f4b';
  const red = light ? '#d24a32' : '#e85639';
  const orange = light ? '#ef742a' : '#ff8333';
  const gold = light ? '#ffad38' : '#ffc24a';
  const hot = light ? '#ffe07d' : '#ffdf78';
  const core = light ? '#fff0be' : '#fff0b2';

  function box(x,y,w,h,color){
    c.fillStyle=color;c.fillRect(Math.round(x),Math.round(y),Math.max(1,Math.round(w)),Math.max(1,Math.round(h)));
  }
  function face(points,color) {
    const ys = points.map(p=>p[1]);
    for(let y=Math.ceil(Math.min(...ys)-.5); y<Math.ceil(Math.max(...ys)-.5); y++){
      const intersections=[];
      for(let i=0,j=points.length-1;i<points.length;j=i++){
        const a=points[i],b=points[j],line=y+.5;
        if((a[1]<=line&&b[1]>line)||(b[1]<=line&&a[1]>line))
          intersections.push(a[0]+(line-a[1])*(b[0]-a[0])/(b[1]-a[1]));
      }
      intersections.sort((a,b)=>a-b);
      for(let i=0;i+1<intersections.length;i+=2){
        const x=Math.ceil(intersections[i]-.5),end=Math.ceil(intersections[i+1]-.5);
        if(end>x)box(x,y,end-x,1,color);
      }
    }
  }
  function segment(x,y,ex,ey,color,width=1) {
    const steps=Math.max(1,Math.ceil(Math.max(Math.abs(ex-x),Math.abs(ey-y))));
    for(let i=0;i<=steps;i++)box(x+(ex-x)*i/steps-width/2,y+(ey-y)*i/steps-width/2,width,width,color);
  }
  function path(points,color,width=1) {
    for(let i=1;i<points.length;i++)segment(...points[i-1],...points[i],color,width);
  }
  function spark(x,y,size,color,bright=false) {
    box(x-size/2,y-size/2,size,size,color);
    if(bright){box(x,y-1,.8,2,core);box(x-1,y,2,1,hot);}
  }
  function tongue(x,y,w,h,bend,phase=0) {
    const sway=sin(angle+phase)*Math.min(2,h*.06);
    function layer(width,height,dx,color) {
      const l=[],r=[];
      for(let i=0;i<=9;i++){
        const k=i/9, a=k*height, off=bend*a*a + sway*a + sin(a*4.2+phase)*w*.065*a;
        const half=w*.5*width*(1-k)*(.88+.39*sin(k*4.4));
        l.push([x+dx+off-half,y-h*a]);r.push([x+dx+off+half,y-h*a]);
      }
      face([...l,...r.reverse()],color);
    }
    layer(1,1,0,ash);layer(.80,.88,0,red);layer(.61,.74,-.15,orange);layer(.38,.51,.25,gold);
  }
  function camp(baseSize) {
    const k=baseSize;
    // A low, living fire leaves the profile of each new stage clear.
    tongue(-4*k,-1,10*k,11*k,-3,1);
    tongue(1*k,-1,13*k,17*k,3.5);
    tongue(5*k,-1,7*k,9*k,3.5,2);
    face([[-13*k,.4],[-12*k,-2],[11*k,2],[13*k,3],[12*k,4.9],[10*k,5.2],[-13*k,1.6]],ink);
    segment(-11*k,-.8,11*k,3.5,bark,2);
    segment(-8*k,-.9,7*k,1.9,grain);
    face([[-13*k,3],[-11*k,1.7],[11*k,-2.4],[13*k,-1.9],[14*k,-.2],[12*k,1.6],[-9*k,5.6],[-12*k,5.9]],ink);
    segment(-10*k,3.8,12*k,-.6,bark,2.4);
    segment(-8*k,2.7,10*k,-.7,grain,1);
    box(-12*k,3.2,2.8*k,2,birch);box(-11*k,4,1,1,grain);
    for(const x of [-4,1,6])box(x*k,.8+(x%2),2,1,x===1?hot:orange);
  }
  function ground() {
    if(mini)return;
    c.save(); c.globalAlpha = light ? .37 : .57;
    face([[-38,1],[-25,-2],[-5,-4],[17,-2],[36,1],[39,3],[19,5],[-19,6],[-35,4]],shade);
    c.restore();
    for(const [x,y] of [[-24,2],[-29,4],[23,1],[31,2],[17,6]])box(x,y,3,1,light?grain:bark);
  }
  // Catmull-Rom through the plotted silhouette, drawn as discrete connected ember dashes.
  function curve(points,u){
    const n=points.length-1,q=Math.max(0,Math.min(n-.00001,u*n)),i=Math.floor(q),f=q-i;
    const a=points[Math.max(0,i-1)],b=points[i],d=points[i+1],e=points[Math.min(n,i+2)];
    return [0,1].map(k=>.5*(2*b[k]+(-a[k]+d[k])*f+
      (2*a[k]-5*b[k]+4*d[k]-e[k])*f*f+(-a[k]+3*b[k]-3*d[k]+e[k])*f*f*f));
  }
  function vortex() {
    const points=[[-3,-4],[-15,-8],[-26,-21],[-27,-36],[-16,-48],[1,-53],[17,-49],[25,-38],[25,-27],[15,-20],[3,-22],[-5,-30],[-3,-38],[4,-41],[10,-37],[8,-32]];
    const v=u=>{const [x,y]=curve(points,u);return [x*(mini?.96:1.38)+sin(angle+u*6)*1.4*u,y*(mini?.96:1.13)+.9*cos(angle+u*4)*u];};
    // Broken rather than concentric rings: a single line rises from the fire and curls inwards.
    const N=39;
    for(let i=0;i<N;i++){
      const u=i/N, a=v(u),b=v(Math.min(1,u+.021)), w=(1.12-u*.29)*(mini?2.9:3.4);
      segment(...a,...b,ash,w+1.9);
      segment(...a,...b,orange,w);
      if(i%3!==2)segment(...a,...b,gold,Math.max(1,w-1.45));
    }
    for(let i=0;i<11;i++){
      const u=(i/11+phase)%1, p=v(u);
      spark(p[0],p[1],i%3===0?3:2,hot,i===1||i===7);
    }
    for(const [x,y] of [[-23,-4],[17,-3]])tongue(x*(mini?.74:1.2),y,6,7+1.1*wave,x*.11,2);
    camp(mini?.84:1);
  }
  function treeTrunk(x,h,side,wide,jagged) {
    // Coordinates are measured upwards from the roots; positive local x faces fire.
    const p=points=>points.map(([xx,yy])=>[x+side*xx*wide,-yy*h]);
    const shape=(a,color)=>face(p(a),color);
    const ridge=(a,color,w)=>path(p(a),color,w);
    shape([[-8,0],[-3, .13],[-1.5,.3],[-2.9,.52],[-2.5,.69],[-4,.85],[-4.5,1],[-1.6,1],[-.5,.84],[1.3,.7],[1.9,.57],[1.2,.35],[3.3,.15],[7,0],[2.6,.045],[-1,0]],ink);
    shape([[-3,.08],[-.2,.17],[.1,.34],[-1.2,.56],[-1,.72],[-2.8,.96],[-1.7,.97],[.6,.72],[1.5,.58],[.9,.35],[2.1,.16],[5,.03],[1.3,.08]],bark);
    ridge([[.5,.17],[.4,.36],[-1.1,.51]],grain,1);
    ridge([[-1.3,.70],[-1.8,.80],[-3,.92]],grain,1);
    const branches=jagged ? [
      [[-1,.55],[5,.68],[10,.73],[13,.81]],[[-1,.65],[-9,.75],[-13,.87]],
      [[-2,.82],[2,.88],[4.5,1.02]]
    ]:[
      [[-1,.55],[5,.67],[11,.715],[14,.80]],[[-1,.68],[-8,.77],[-12,.87]],
      [[-3,.80],[1.5,.89],[4,.99]]
    ];
    for(const b of branches){ridge(b,ink,mini?2:2.6);ridge(b.map(([xx,yy])=>[xx+.2,yy-.016]),bark,1);}
    // Reflection climbs in packets along the centre-facing bark.
    const heat=(phase+(side===1?.08:.51))%1;
    for(let i=0;i<15;i++){
      const u=.04+i*.057,xx=1.4-2.8*u+sin(u*7)*1.3,shine=Math.max(0,1-Math.abs(u-heat)/.27);
      ridge([[xx,u],[xx-.4,u+.045]],shine>.57?hot:shine>.20?gold:grain,shine>.6?2.3:1.3);
    }
  }
  function reflect() {
    const spread=mini?20:49, heights=mini?[53,46]:[71,59];
    for(const [i,dir] of [[0,-1],[1,1]]){
      const x=dir*spread, k=mini?1.15:1.5,h=heights[i];
      const shadowLen=mini?12+wave*2.5:24+wave*7;
      face([[x-2,-1],[x+2,-1],[x+dir*shadowLen*.72,3],[x+dir*shadowLen,5],[x+dir*5,3]],shade);
      // A few cool needles above the fork show that only the bark is reflecting the fire.
      face([[x+dir*.8*k,-h*.87],[x+dir*6.7*k,-h*.88],[x+dir*9.4*k,-h*.95],
        [x+dir*8.4*k,-h*.89],[x+dir*12.4*k,-h*.91],[x+dir*9.7*k,-h*.84],
        [x+dir*11*k,-h*.85],[x+dir*7*k,-h*.80],[x+dir*8*k,-h*.80],[x+dir*3.3*k,-h*.76]],leaf);
      treeTrunk(x,h,-dir,k,false);
      const inner=x+dir*2*k;
      path([[inner,-h*.14],[inner-dir*1*k,-h*.39],[inner+dir*2*k,-h*.61],[inner+dir*2*k,-h*.7]],bark,mini?1.8:2.5);
      const point=mini?4:7;
      for(let j=0;j<3;j++)box(x-dir*(point+j*2),1+j,mini?2:3,1,j===0?gold:grain);
    }
    camp(mini?.85:1);
  }
  function pineShape(x,h,r,m,paint,outline) {
    const coords=[[-.13,0],[-.11,.16],[-.60,.15],[-.47,.22],[-1,.18],[-.71,.30],[-.85,.32],
      [-.49,.42],[-.67,.40],[-.43,.51],[-.58,.50],[-.32,.62],[-.42,.61],[-.21,.74],[-.26,.72],[-.08,.89],[.03,1],
      [.15,.81],[.24,.76],[.19,.76],[.42,.60],[.33,.62],[.62,.48],[.46,.50],[.73,.37],[.62,.38],[.86,.30],[.75,.30],[1,.18],[.57,.20],[.70,.14],[.13,.16],[.16,0]];
    const pts=coords.map(([xx,u])=>[x+xx*r*m,-u*h]);
    face(pts,paint);
    if(outline)path([...pts,pts[0]],outline,1);
  }
  function bough() {
    const x=mini?-23:-48,h=mini?49:62,r=mini?10:17;
    pineShape(x,h,r,1,leaf,ink);
    treeTrunk(x,h*.94,1,mini?.63:1,true);
    const nodes=mini?[[x,-14],[-17,-23],[-8,-23],[2,-29],[12,-28],[22,-34],[29,-34]]:
      [[x,-17],[-35,-29],[-21,-29],[-6,-36],[10,-36],[22,-42],[32,-42]];
    path(nodes,ink,mini?4:5.2);path(nodes.map(([a,b])=>[a,b-.6]),grain,mini?2:2.6);
    const fork=nodes[3];path([fork,[fork[0]+2,fork[1]-5],[fork[0]+6,fork[1]-7]],bark,2);
    for(let i=1;i<nodes.length-1;i++){
      const [xx,yy]=nodes[i];const localPhase=((phase+.3-i*.15)%1+1)%1;
      const pulse=.55+.45*cos((localPhase-.5)*tau);
      tongue(xx+1,yy+1,mini?6.2:8,4+9*pulse,2.2,2+i);
    }
    const k=(phase+.38)%1;const active=curve(nodes,k);
    for(let i=0;i<5;i++){
      const tail=curve(nodes,Math.max(0,k-i*.043));spark(...tail,i===0?3:1.3,i===0?hot:gold);
    }
    spark(active[0],active[1]-3,2,hot,true);
    camp(mini?.78:1);
  }
  function burningPine(x,h,r,offset) {
    pineShape(x,h,r,1,ash,ink);
    const at=(xx,u)=>[x+xx*r,-u*h];
    const draw=(coords,color)=>face(coords.map(([xx,u])=>at(xx,u)),color);
    draw([[-.17,0],[-.12,.33],[-.24,.54],[-.10,.76],[.01,.97],[.10,.82],[.07,.60],[.24,.43],[.12,.24],[.18,.01]],ink);
    draw([[0,.12],[-.28,.29],[-.04,.26],[-.42,.46],[-.12,.38],[-.32,.59],[-.08,.49],[-.15,.72],[-.01,.68],[.04,.94],[.13,.75],[.09,.63],[.29,.68],[.15,.50],[.45,.58],[.22,.39],[.52,.44],[.24,.29],[.62,.32],[.18,.20]],red);
    // Horizontal boughs form the readable fir triangle; the bright wave climbs its tiers.
    const heat=(phase+offset)%1;
    for(let tier=0;tier<5;tier++){
      const u=.23+tier*.145, a=(1-u)*1.08;
      const dist=Math.abs(u-heat), glow=Math.max(0,1-Math.min(dist,1-dist)/.35);
      for(const dir of [-1,1]){
        const reach=(dir>0?.97:1)*a;
        const lift= .045*cos(angle+tier*.8+dir);
        const points=[[0,u-.035],[dir*reach*.44,u+.003],[dir*reach*.62,u+.11],
          [dir*reach*.64,u+.075],[dir*reach,u+.19+lift],[dir*reach*.91,u+.091],
          [dir*reach*.96,u+.055],[dir*reach*.61,u-.01],[dir*reach*.84,u-.008],[dir*reach*.39,u-.059],[0,u-.067]];
        draw(points,orange);
        draw([[0,u-.035],[dir*reach*.38,u+.005],[dir*reach*.52,u+.060],[dir*reach*.49,u+.032],
          [dir*reach*.83,u+.10+lift],[dir*reach*.65,u+.027],[dir*reach*.41,u-.013],[dir*reach*.40,u-.032]],
          glow>.65?hot:gold);
        path([at(0,u-.045),at(dir*reach*.37,u-.038),at(dir*reach*.7,u-.02)],ash,mini?1:1.4);
      }
    }
    tongue(x+.5,-h*.79,r*.48,h*.21,1.8,offset*3);
    path([at(0,.01),at(.045,.19),at(-.06,.38),at(.02,.56),at(.015,.68)],ink,mini?2:2.8);
    path([at(.08,.02),at(.10,.17),at(-.025,.35),at(.055,.48)],grain,1);
    const glow=at(.11*sin(heat*7),.15+heat*.7);
    box(glow[0],glow[1],2,2,hot);
  }
  function oneTree() {
    const x=mini?-11:-21,h=mini?54:74,r=mini?19:30;
    burningPine(x,h,r,.17);
    camp(mini?.55:.75);
  }
  function twoTrees() {
    const left=mini?-19:-52,right=mini?19:46,lH=mini?49:68,rH=mini?36:49;
    burningPine(left,lH,mini?12.5:20,.04);
    burningPine(right,rH,mini?12:18,.51);
    const delta=right-left,turn=Math.floor(phase*2+.38)%2,flight=(phase*2+.38)%1;
    const at=u=>[left+delta*u,-lH*.89+(lH-rH)*u-(mini?9:17)*4*u*(1-u)];
    for(let i=0;i<=8;i++){
      const u=.09+i*.10;
      const p=at(u);box(p[0],p[1],mini?1:2,1,i%2===0?grain:orange);
    }
    for(let i=0;i<7;i++){
      const u=flight-i*(mini?.035:.029);
      if(u<0) continue;
      const p=at(turn===0?u:1-u);
      spark(p[0],p[1],i===0?3.2:i<4?2:1,i===0?hot:i<3?gold:orange,i===0);
    }
    camp(mini?.65:.86);
  }
  c.save();
  ground();
  if(day>=75)twoTrees();
  else if(day>=60)oneTree();
  else if(day>=49)bough();
  else if(day>=42)reflect();
  else vortex();
  c.restore();
}
