const { chromium } = require('playwright');
const { createClient } = require('@supabase/supabase-js');
const DEMO_URL='https://vtzqjmazsvurxdeondmi.supabase.co';
const DEMO_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8';
const KANIT='/home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/ui-kapi-kanit/';
async function browser(){ return chromium.launch({executablePath:process.env.HOME+'/.cache/ms-playwright/chromium-1228/chrome-linux64/chrome',args:['--no-sandbox']}); }
async function ctx(b,demoFlag=true){
  const c=await b.newContext({viewport:{width:390,height:844},locale:'tr-TR'});
  if(demoFlag) await c.addInitScript(()=>{localStorage.setItem('EGESUT_DEMO','1');localStorage.setItem('EGESUT_DEMO_POPUP_OFF','1');});
  return c;
}
async function db(){ const d=createClient(DEMO_URL,DEMO_KEY); const {error}=await d.auth.signInWithPassword({email:'demo@egesut.web',password:'demo2026'}); if(error) throw error; return d; }
module.exports={browser,ctx,db,KANIT,BASE:'http://127.0.0.1:8291/'};
