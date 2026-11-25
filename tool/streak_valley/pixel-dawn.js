// Pixel-space sprites. The caller places the origin in the middle of the logs.
function paintPixelDawn(c, day, light, t, mini = false) {
  const time = Math.max(0, Number(t) || 0);
  const {sin, cos, PI, abs, round} = Math;
  const phase=time, angle=phase*2*PI;
  const p = light ? {
    edge:'#392d37', bark:'#674346', wood:'#9a5d45', ring:'#d18e5c', cut:'#edbd8c',
    soot:'#473648', ash:'#766371', smoke:'#766e83', smokeLight:'#928d9c', smokeDark:'#544e66',
    wine:'#982f43', red:'#d74b36', orange:'#fa812d', gold:'#ffb935', sun:'#ffe384',white:'#fff2b9'
  } : {
    edge:'#352a3f', bark:'#68454b',wood:'#aa674b', ring:'#e6a369',cut:'#ffd292',
    soot:'#49404d',ash:'#8d7585', smoke:'#b7b4c5',smokeLight:'#e1dce3',smokeDark:'#817f97',
    wine:'#9d384c',red:'#f1573b',orange:'#ff9234',gold:'#ffcc50',sun:'#ffec93',white:'#fff5cb'
  };
  function px(x,y,w,h,color) {
    c.fillStyle=color;
    c.fillRect(round(x),round(y),Math.max(1,round(w)),Math.max(1,round(h)));
  }
  function face(points,color) {
    c.fillStyle=color;
    const values=points.map(a=>a[1]);
    for(let y=Math.floor(Math.min(...values)); y<Math.ceil(Math.max(...values)); y++){
      const hits=[],yc=y+.5;
      for(let i=0,j=points.length-1;i<points.length;j=i++){
        const a=points[i],b=points[j];
        if((a[1]<=yc&&yc<b[1])||(b[1]<=yc&&yc<a[1]))
          hits.push(a[0]+(yc-a[1])*(b[0]-a[0])/(b[1]-a[1]));
      }
      hits.sort((a,b)=>a-b);
      for(let i=0;i+1<hits.length;i+=2){
        const x=Math.ceil(hits[i]-.5),end=Math.ceil(hits[i+1]-.5);
        if(end>x)c.fillRect(x,y,end-x,1);
      }
    }
  }
  function dash(x1,y1,x2,y2,color,thickness=1) {
    const n=Math.max(1,Math.ceil(Math.max(abs(x2-x1),abs(y2-y1))));
    for(let i=0;i<=n;i++)px(x1+(x2-x1)*i/n,y1+(y2-y1)*i/n,thickness,thickness,color);
  }
  function logs() {
    face([[-15,-3],[-13,-5],[-10,-5],[14,2],[15,4],[12,6],[-13,0]],p.edge);
    face([[-13,-4],[-10,-4],[12,2],[12,4],[-12,-1]],p.bark);
    dash(-12,-4,10,2,p.wood);
    face([[-15,3],[-12,1],[11,-4],[14,-4],[16,-2],[15,1],[-11,7],[-14,6]],p.edge);
    face([[-12,2],[12,-3],[14,-3],[13,0],[-10,5]],p.bark);
    dash(-9,2,12,-2,p.wood);
    px(-14,3,4,3,p.cut);px(-13,2,2,1,p.ring);px(-13,3,1,2,p.wood);
    px(12,3,2,2,p.ring);
  }
  function driftingSmoke() {
    const h=mini?24:34;
    const sway=sin(angle);
    // Across each horizontal slice of the S curve the darker edge rounds into
    // a pale face. Its width grows, curls back, then disperses into the breeze.
    for(let row=0;row<h;row++){
      const u=row/(h-1);
      const x=-1+u*6 + (sin(u*8.1-angle)*(.3+u)*7.1 + sin(angle)*2.0*u);
      const half=1.0+3.7*Math.pow(sin(u*PI),.7);
      c.globalAlpha=.97-.44*u;
      px(x-half-1,-4-row,2*half+2,1,p.smokeDark);
      px(x-half+.3,-4-row,1.6*half+1,1,p.smoke);
      if(u>.15&&u<.87)px(x-half+1,-4-row,Math.max(1,half*.58),1,p.smokeLight);
    }
    c.globalAlpha=.36;
    const tail=6+7.8*sin(8.1-angle)+2*sin(angle);
    dash(tail,-h-4,tail+3+sway,-h-5,p.smoke,1);
    c.globalAlpha=1;
  }
  function emberInSplitLog() {
    const breath=(1+sin(angle))*.5;
    const y=-7, rx=13+2*breath,ry=7+2*breath;
    for(let j=0;j<42;j++){
      const a=j*PI/21,nearFoot=sin(a)>.73;
      if(nearFoot)continue;
      c.globalAlpha=.46+.31*breath;
      px(cos(a)*rx-1,y+sin(a)*ry,mini?2:1.7,1.5,p.orange);
    }
    c.globalAlpha=1;
    face([[-17,0],[-16,-5],[-13,-7],[-5,-9],[3,-10],[14,-9],[17,-7],[15,-3],
      [10,0],[-6,3],[-14,3]],p.edge);
    face([[-15,-3],[-13,-6],[-4,-8],[5,-9],[13,-8],[15,-7],[12,-5],[3,-4],[-7,-2]],p.soot);
    dash(-13,-6,-5,-8,p.ash);dash(7,-9,12,-9,p.ash);
    face([[-12,-4],[-8,-7],[-4,-6],[-1,-10],[4,-10],[6,-8],[12,-8],[10,-4],[5,-2],[-1,-1],[-8,-1]],p.wine);
    face([[-10,-4],[-6,-6],[-3,-5],[1,-8],[4,-9],[5,-7],[9,-7],[7,-4],[2,-2],[-6,-2]],p.orange);
    c.globalAlpha=.55+.43*breath;
    face([[-6,-4],[-3,-5],[0,-4],[3,-8],[5,-7],[5,-5],[2,-3],[-4,-3]],p.sun);
    c.globalAlpha=1;
    dash(-10,-2,-6,-4,p.soot);dash(11,-7,7,-5,p.edge);
    face([[-14,0],[-6,-1],[0,-3],[3,-2],[11,-4],[8,0],[0,2],[-10,4],[-14,3]],p.bark);
    dash(-11,2,-5,1,p.wood);
    px(-15,-1,2,3,p.cut);
  }
  function shootingSpark() {
    const arc=s=>({x:-4+8.5*sin(s*2*PI+.67),y:-21-5.6*sin(s*2*PI+.12)});
    const compress=mini?.80:1;
    for(let i=7;i>=1;i--){
      const a=arc(phase-i*.031);
      c.globalAlpha=.82-i*.087;
      px(a.x-i*.55,a.y*compress+1.1*i+(i*i)*.075,i<4?2:1,1+(i%2),i<4?p.gold:p.orange);
    }
    c.globalAlpha=1;
    const a=arc(phase), x=a.x,y=a.y*compress, long=6.7+.8*sin(angle+.4);
    const star=(scale,color)=>face([[0,-long-1],[1.7,-2.3],[long-.2,-.4],[2,.7],
      [.2,long+.4],[-1.7,1.5],[-long,0],[-2,-1.4]].map(([dx,dy])=>[x+dx*scale,y+dy*scale]),color);
    star(1.24,p.wine);star(1,p.gold);star(.57,p.white);
    px(x-.6,y-1.5,2,3,p.white);
    px(0,-5,3,2,p.red);px(1,-5,1,1,p.gold);
  }
  function petal(x,y,width,height,bend) {
    function layer(w,h,bias,color){
      const left=[],right=[];
      for(let i=0;i<=12;i++){
        const u=i/12, k=h*u;
        const axis=x+bend*k*k+bias;
        const half=width*w*(.20+.72*Math.pow(sin(u*PI),.92))*(1-.71*u);
        left.push([axis-half,y-height*k]);
        right.push([axis+half,y-height*k]);
      }
      face([...left,...right.reverse()],color);
    }
    layer(1,1,0,p.wine);layer(.82,.94,0,p.red);
    layer(.64,.84,0,p.orange);layer(.43,.66,-.1,p.gold);layer(.21,.39,-.2,p.white);
  }
  function matchFlame() {
    const open=.5+.5*sin(angle+.35);
    petal(-.5,-3,3.9,12+7*open,7.5-6.0*open);
    px(-1,-4,3,2,p.sun);
  }
  function kindling() {
    const fan=[[-10,-3,-4.5,0],[0,-5,.5,1.92],[9,-3,4.0,3.8]];
    for(let i=0;i<fan.length;i++){
      const [x,y,lean,phase]=fan[i];
      const flare=(1+cos(angle*2-phase))*.5;
      const height=(i===1?10:7)+flare*6;
      petal(x,y,3.4+flare*.65,height,lean+sin(angle+phase)*.75);
    }
    for (const [xa,ya,xb,yb] of [[-15,3,3,-4],[-10,-4,13,4],[-11,4,13,-3],[-4,-3,12,3]]){
      dash(xa,ya,xb,yb,p.edge,2);dash(xa,ya,xb,yb,p.wood);
      px(xa,ya,1,1,p.cut);
    }
    dash(-9,-2,0,2,p.gold);dash(4,-1,8,-2,p.orange);
  }
  c.save();
  if(day===1){driftingSmoke();logs();}
  else if(day===2){logs();emberInSplitLog();}
  else if(day===3){logs();shootingSpark();}
  else if(day===4){matchFlame();logs();}
  else if(day===5){kindling();}
  c.restore();
}
