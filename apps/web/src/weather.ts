import {call,isNative} from './bridge';
export type WeatherLocation = {name:string;latitude:number;longitude:number};
export type DayWeather = {location:string;minimum:number|null;maximum:number|null;precipitation:number|null;code:number|null};

export const DEFAULT_WEATHER_LOCATION: WeatherLocation = {name:'Provo, Utah',latitude:40.2338,longitude:-111.6585};
const locationKey='memory-catcher.weather-location.v1';

export function readWeatherLocation(): WeatherLocation {
  try { const value=localStorage.getItem(locationKey); if(value){const parsed=JSON.parse(value);if(typeof parsed.name==='string'&&Number.isFinite(parsed.latitude)&&Number.isFinite(parsed.longitude))return parsed;} } catch {}
  return DEFAULT_WEATHER_LOCATION;
}

export async function findWeatherLocation(query:string):Promise<WeatherLocation>{
  const url=new URL('https://geocoding-api.open-meteo.com/v1/search');url.searchParams.set('name',query);url.searchParams.set('count','1');url.searchParams.set('language','en');url.searchParams.set('format','json');
  const response=await fetch(url);if(!response.ok)throw new Error('Could not find that weather location.');
  const data=await response.json();const place=data.results?.[0];if(!place)throw new Error('No matching city found. Try adding a state or country.');
  const name=[place.name,place.admin1,place.country].filter(Boolean).join(', ');
  return {name,latitude:place.latitude,longitude:place.longitude};
}

export function saveWeatherLocation(location:WeatherLocation){localStorage.setItem(locationKey,JSON.stringify(location));}

type WeatherRecord={at:number;value:DayWeather};
const weatherMemory=new Map<string,WeatherRecord>();
const weatherRequests=new Map<string,Promise<DayWeather>>();
export async function weatherForDay(location:WeatherLocation,day:string,force=false):Promise<DayWeather>{
  const key=JSON.stringify([location.name,location.latitude,location.longitude,day,'F',2]);
  const existing=weatherRequests.get(key);if(existing)return existing;
  const work=(async()=>{
    let cached=weatherMemory.get(key);
    if(!cached&&isNative())try{const {payload}=await call('weather.cache.get',{key});if(payload){const item=JSON.parse(payload) as WeatherRecord;if(Number.isFinite(item.at)&&item.value?.location===location.name)cached=item;}}catch{}
    if(cached&&!force&&Date.now()-cached.at>=0&&Date.now()-cached.at<86400000){weatherMemory.set(key,cached);return cached.value;}
    try{
      const value=await fetchWeather(location,day),record={at:Date.now(),value};weatherMemory.set(key,record);
      if(isNative())await call('weather.cache.save',{key,payload:JSON.stringify(record)});
      return value;
    }catch(error){if(cached&&!force)return cached.value;throw error;}
  })();
  weatherRequests.set(key,work);
  try{return await work;}finally{weatherRequests.delete(key);}
}

async function fetchWeather(location:WeatherLocation,day:string):Promise<DayWeather>{
  const today=new Date();const todayString=`${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`;
  const dateNumber=(value:string)=>{const match=/^(\d{4})-(\d{2})-(\d{2})$/.exec(value);if(!match)throw new Error('Invalid weather date.');const [,year,month,date]=match;const timestamp=Date.UTC(Number(year),Number(month)-1,Number(date));if(new Date(timestamp).toISOString().slice(0,10)!==value)throw new Error('Invalid weather date.');return timestamp;};
  const daysAgo=Math.round((dateNumber(todayString)-dateNumber(day))/86_400_000);
  const recentPast=daysAgo>0&&daysAgo<=7;const historical=daysAgo>7;
  const url=new URL(historical?'https://archive-api.open-meteo.com/v1/archive':'https://api.open-meteo.com/v1/forecast');
  url.searchParams.set('latitude',String(location.latitude));url.searchParams.set('longitude',String(location.longitude));url.searchParams.set('daily','temperature_2m_min,temperature_2m_max,precipitation_sum,weather_code');url.searchParams.set('temperature_unit','fahrenheit');url.searchParams.set('timezone','auto');
  if(historical){url.searchParams.set('start_date',day);url.searchParams.set('end_date',day);}
  else if(recentPast){url.searchParams.set('past_days','7');url.searchParams.set('forecast_days','16');}
  else{url.searchParams.set('start_date',day);url.searchParams.set('end_date',day);}
  const response=await fetch(url,{cache:'no-store',signal:AbortSignal.timeout(15000)});if(!response.ok)throw new Error('Weather is temporarily unavailable.');const data=await response.json();
  const index=data.daily?.time?.indexOf(day)??-1;if(index<0)throw new Error('No weather data is available for this day.');
  return {location:location.name,minimum:data.daily.temperature_2m_min?.[index]??null,maximum:data.daily.temperature_2m_max?.[index]??null,precipitation:data.daily.precipitation_sum?.[index]??null,code:data.daily.weather_code?.[index]??null};
}

export function weatherDescription(code:number|null){if(code===null)return 'Conditions unavailable';if(code===0)return 'Sunny';if(code<=3)return 'Partly cloudy';if(code===45||code===48)return 'Fog';if(code>=51&&code<=67)return 'Drizzle or rain';if(code>=71&&code<=77)return 'Snow';if(code>=80&&code<=82)return 'Rain showers';if(code>=85&&code<=86)return 'Snow showers';if(code>=95)return 'Thunderstorms';return 'Mixed conditions';}
