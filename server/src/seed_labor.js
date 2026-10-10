/** 微劳动 / 社区 / 风控 / 银行专员 种子数据 */
import { hashPassword } from './auth.js';
import { nowIso, one, r2, run } from './db.js';
import { seedRisk } from './services/risk.js';
import { TASK_TYPES } from './services/labor.js';

// [ext_id, 手机, 昵称/机构, role, 钱包, bank_code]
const ACCOUNTS = [
  ['M2001', '13900002001', '星辰品牌', 'merchant', 200000, null],
  ['M2002', '13900002002', '云栖餐饮集团', 'merchant', 120000, null],
  ['M2003', '13900002003', '橙光教育', 'merchant', 80000, null],
  ['M2004', '13900002004', '鲜丰水果', 'merchant', 60000, null],
  ['M2005', '13900002005', '星光云官方', 'merchant', 500000, null],
  ['M2006', '13900002006', '数智标注', 'merchant', 90000, null],
  ['B3001', '13900003001', '招商银行 · 顾承业', 'bank', 0, 'CMB'],
  ['B3002', '13900003002', '马上消费金融 · 李清', 'bank', 0, 'MSXF'],
  ['R4001', '13900004001', '风控 · 陈锐', 'risk', 0, null],
  ['O5001', '13900005001', '运营 · 周梦', 'ops', 0, null],
];

// [商家 ext, 类型, 标题, 说明, 报酬, 名额, 现金%, kyc, 交付时限h, 要求[], 标签[], 城市]
const TASKS = [
  ['M2001', 'content', '「星辰晨露精华」30 秒短视频种草', '拍摄 30~60 秒竖版短视频，真实展示上脸质地与使用感受，发布到抖音或小红书。', 380, 50, 40, 2, 120, ['竖版 30~60 秒，真人出镜或手部特写', '口播或字幕提到「敏感肌可用」', '发布后提交作品链接 + 后台数据截图', '保留原始素材 30 天'], ['美妆', '短视频'], null],
  ['M2001', 'content', '氨基酸洁面乳 · 小红书图文笔记', '写一篇 300 字以上真实使用笔记，配 3 张以上实拍图。', 120, 100, 40, 2, 96, ['正文 ≥ 300 字，真实体验', '实拍图 ≥ 3 张，不得盗图', '带话题 #敏感肌洁面'], ['美妆', '图文'], null],
  ['M2001', 'promo', '私域社群分享新品体验装', '把品牌新品体验装链接分享到你的微信群或朋友圈，每位领取的新用户计 1 份。', 8, 500, 50, 1, 168, ['分享到 ≥ 1 个 50 人以上的群', '提交分享截图'], ['推广'], null],
  ['M2001', 'survey', '护肤习惯调研问卷（15 题）', '帮助品牌了解 20~35 岁用户的护肤习惯，约 5 分钟完成。', 15, 800, 30, 1, 24, ['如实填写', '提交完成页截图'], ['问卷'], null],
  ['M2002', 'visit', '新店开业「神秘顾客」到店体验', '到指定门店用餐，从环境、服务、出餐速度、口味 4 个维度打分并拍照。餐费另报销。', 150, 30, 60, 2, 72, ['到店拍门头 + 菜品 + 小票', '填写体验评分表', '不得提前告知店员身份'], ['餐饮', '探店'], '上海'],
  ['M2002', 'visit', '门店菜单与价签核查', '到店核对菜单价格是否与线上一致，拍照记录差异。', 60, 40, 60, 2, 48, ['拍完整菜单', '标注差异项'], ['餐饮'], '杭州'],
  ['M2002', 'skill', '团购套餐文案与主图设计', '为 3 家新店设计美团/抖音团购主图与卖点文案。', 680, 5, 50, 3, 168, ['每家 3 张主图（1:1）', '每家 5 条卖点文案', '提供源文件'], ['设计', '餐饮运营'], null],
  ['M2002', 'content', '探店短视频 · 火锅双人餐', '到店拍摄 30 秒探店视频，展示环境与菜品，发布到抖音并@品牌。', 260, 20, 40, 2, 120, ['到店实拍，不得使用素材库', '视频 ≥ 30 秒', '提交作品链接'], ['探店', '短视频'], '上海'],
  ['M2003', 'service', 'AI 陪练课程夜间在线客服（19:00-23:00）', '在企业微信接待家长咨询，按话术回复，AI 助手可辅助。每晚一班。', 150, 20, 60, 3, 168, ['完成岗前 30 分钟培训', '每班接待 ≥ 20 人', '响应时间 ≤ 2 分钟'], ['客服', '远程'], null],
  ['M2003', 'service', '课程回访电话（每 10 通）', '按名单回访已购课家长，记录满意度与续费意向。', 45, 60, 60, 2, 72, ['每 10 通为 1 份', '录入回访表'], ['客服', '电话'], null],
  ['M2003', 'content', '「AI 口语陪练」体验测评文章', '体验 7 天课程后写一篇 800 字测评，客观说明优缺点。', 300, 15, 40, 2, 240, ['≥ 800 字', '包含 3 张使用截图', '可以写缺点'], ['教育', '测评'], null],
  ['M2003', 'survey', '家长教育支出调研（20 题）', '了解家庭在课外教育上的支出结构，约 8 分钟。', 20, 600, 30, 1, 24, ['如实填写'], ['问卷'], null],
  ['M2004', 'visit', '社区水果店陈列拍照', '到附近鲜丰水果门店拍摄水果陈列与价签，帮助总部巡检。', 25, 200, 70, 1, 24, ['拍 6 张以上', '包含价签特写'], ['零售', '巡店'], '杭州'],
  ['M2004', 'errand', '同城水果配送（3 公里内）', '从门店取货送到指定小区，每单 1 份。需自备电动车。', 12, 300, 80, 3, 4, ['取货拍照', '送达拍照', '准时送达'], ['跑腿', '配送'], '杭州'],
  ['M2004', 'promo', '社区团购群新人拉新', '邀请邻居加入门店社区团购群并完成首单，每有效新人计 1 份。', 10, 400, 50, 1, 168, ['提交邀请截图'], ['推广', '社区'], null],
  ['M2004', 'content', '「当季水果」开箱短视频', '收到水果箱后拍 20 秒开箱视频。', 80, 60, 40, 2, 96, ['竖版 20 秒以上', '展示果品细节'], ['开箱', '生鲜'], null],
  ['M2005', 'survey', '星光云使用体验问卷（12 题）', '平台官方调研，帮我们把产品做得更好。', 10, 3000, 0, 1, 24, ['如实填写'], ['官方', '问卷'], null],
  ['M2005', 'content', '我的轻松清偿故事 · 征文', '分享你使用星光云的真实经历，优秀作品将在社区精选展示。', 200, 100, 30, 2, 336, ['≥ 600 字真实经历', '可匿名，不得泄露他人信息'], ['官方', '征文'], null],
  ['M2005', 'promo', '邀请好友体验星光云', '邀请好友注册并完成首单购物，每位计 1 份。', 15, 1000, 40, 2, 336, ['好友需为新用户', '完成实名 + 首单'], ['官方', '推广'], null],
  ['M2005', 'label', 'App 功能易用性测试', '按测试用例操作 10 个功能并记录问题，约 30 分钟。', 50, 200, 40, 2, 48, ['按用例逐条记录', '截图说明问题'], ['测试', '远程'], null],
  ['M2006', 'label', '商品图片分类标注（每 200 张）', '按类目对商品图片打标签，在线标注工具完成。', 30, 500, 60, 2, 24, ['准确率 ≥ 95%（抽检）', '每 200 张为 1 份'], ['标注', '远程'], null],
  ['M2006', 'label', '语音转写校对（每 30 分钟音频）', '校对 AI 语音转写结果，修正错别字与标点。', 40, 300, 60, 2, 48, ['准确率 ≥ 98%', '方言另计'], ['标注', '远程'], null],
  ['M2006', 'label', '对话质量打分（每 100 条）', '为 AI 客服对话打分，判断回答是否准确礼貌。', 35, 400, 60, 2, 24, ['按评分标准打分', '抽检一致率 ≥ 90%'], ['标注', 'AI'], null],
  ['M2006', 'skill', '短视频字幕与剪辑（每条 1 分钟内）', '为品牌素材剪辑并加字幕，提供工程文件。', 90, 80, 50, 3, 48, ['1080P 导出', '字幕无错字', '提供工程文件'], ['剪辑', '技能'], null],
  ['M2002', 'errand', '门店物料跑腿（同城）', '从总部取宣传物料送到指定门店。', 30, 50, 80, 3, 6, ['取件拍照', '交付签收'], ['跑腿'], '上海'],
  ['M2003', 'skill', '课程海报设计（3 张）', '按品牌规范设计 3 张课程宣传海报。', 360, 6, 50, 3, 120, ['提供 PSD/AI 源文件', '尺寸 1080×1920'], ['设计'], null],
];

const POSTS = [
  ['U1002', '我是怎么在 10 个月里偿清两张卡的', '一开始我也很焦虑，每个月账单一来就失眠。后来把账单都接到星光云，先清偿金额最小的那张，拿到银行的偿清证明那天真的哭了。\n\n我的方法很简单：日常买东西都在商城下单，晚上下班做一两个问卷和图文任务，清偿金每周都在涨。没有什么捷径，就是让每一笔本来就要花的钱都多一点用处。', ['真实经历', '偿清'], 2, 9632, 1210, 128400],
  ['U1002', '新手做微劳动，这 5 类任务最友好', '1. 问卷调研：5 分钟一份，几乎没门槛\n2. 数据标注：在家就能做，时间灵活\n3. 门店巡检：下楼顺手拍几张照片\n4. 图文笔记：会写字就行，AI 助手可以帮你改\n5. 社群推广：适合群多的朋友\n\n建议先完成实名认证，能接的任务会多很多。', ['微劳动', '新手攻略'], 2, 6410, 920, 86200],
  ['U1001', '第一次接探店任务，拿到 150 块', '周末去了一家新开的火锅店做神秘顾客，吃完认真填了评分表，第二天就验收通过了。60% 直接到钱包，剩下的变成清偿金，顺手又清偿了一点信用卡。', ['探店', '任务接单'], 1, 2140, 388, 32100],
  ['U1001', '记账一个月，发现咖啡钱也能用来清偿', '以前每天一杯咖啡觉得是浪费，现在在星光云买，每杯返一块多清偿金。一个月下来，光咖啡就返了 40 多。积少成多吧。', ['日常消费', '清偿金'], 1, 1820, 266, 21000],
];

export function seedLabor() {
  seedRisk();
  if (one("SELECT id FROM users WHERE ext_id = 'M2001'")) return false;
  const at = nowIso();
  for (const [ext, mobile, name, role, bal, bank] of ACCOUNTS) {
    run('INSERT INTO users (ext_id, mobile, nickname, credit_score, wallet_balance, role, org_name, bank_code, created_at) VALUES (?,?,?,?,?,?,?,?,?)', ext, mobile, name, 700, bal, role, name, bank, at);
  }
  // 演示用户的实名等级：林晓明 L3（未绑卡，演示提现前绑卡），苏雨桐 L4 + 支付密码 135790
  const uid = (e) => one('SELECT id FROM users WHERE ext_id = ?', e).id;
  run('INSERT OR REPLACE INTO kyc (user_id, level, real_name, id_no_mask, updated_at) VALUES (?,?,?,?,?)', uid('U1001'), 3, '林晓明', '330***********1234', at);
  run('INSERT OR REPLACE INTO kyc (user_id, level, real_name, id_no_mask, bank_name, card_mask, pay_pwd, updated_at) VALUES (?,?,?,?,?,?,?,?)', uid('U1002'), 4, '苏雨桐', '310***********5678', '招商银行', '**** 6688', hashPassword('135790'), new Date(Date.now() - 30 * 86400_000).toISOString());
  run("UPDATE users SET skills = ?, city = '杭州' WHERE ext_id = 'U1001'", JSON.stringify(['餐饮运营', '探店', '客服']));
  run("UPDATE users SET skills = ?, city = '上海', labor_level = 3 WHERE ext_id = 'U1002'", JSON.stringify(['短视频', '文案', '美妆']));
  // 旧演示身份里的商家/风控/运营/银行专员（U1003~U1006）映射到对应角色
  run("UPDATE users SET role = 'merchant', org_name = '星辰品牌' WHERE ext_id = 'U1003'");
  run("UPDATE users SET role = 'risk', org_name = '风控中心' WHERE ext_id = 'U1004'");
  run("UPDATE users SET role = 'ops', org_name = '运营中心' WHERE ext_id = 'U1005'");
  run("UPDATE users SET role = 'bank', org_name = '招商银行信用卡中心', bank_code = 'CMB' WHERE ext_id = 'U1006'");

  for (const [ext, type, title, desc, reward, quota, cashPct, kyc, hours, req, tags, city] of TASKS) {
    const m = one('SELECT * FROM users WHERE ext_id = ?', ext);
    const deposit = r2(reward * quota);
    const taken = Math.floor(quota * (0.15 + Math.random() * 0.55));
    run('UPDATE users SET wallet_balance = wallet_balance - ?, wallet_frozen = wallet_frozen + ? WHERE id = ?', deposit, deposit, m.id);
    run(
      `INSERT INTO tasks (task_no, publisher_id, publisher_name, task_type, title, description, requirements, image, reward, cash_pct, clear_pct, fee_pct, boost, quota, taken, done, kyc_required, credit_min, duration_hours, review_hours, tags, city, deposit, deposit_left, status, deadline_at, created_at, updated_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,10,1,?,?,?,?,0,?,72,?,?,?,?,2,?,?,?)`,
      `TK${String(1000 + one('SELECT COUNT(*) n FROM tasks').n + 1)}`, m.id, m.org_name, type, title, desc, JSON.stringify(req), `/media/img/${TASK_TYPES[type].img}.webp`, reward, cashPct, 100 - cashPct, quota, 0, 0, kyc, hours, JSON.stringify(tags), city, deposit, deposit,
      new Date(Date.now() + (7 + Math.floor(Math.random() * 30)) * 86400_000).toISOString(), at, at,
    );
    // 展示用「已报名人数」：直接写 taken（不生成任务单），名额与押金仍按真实计算
    run('UPDATE tasks SET taken = ? WHERE id = ?', taken, Number(one('SELECT MAX(id) id FROM tasks').id));
  }
  for (const [ext, title, body, tags, st, likes, comments, views] of POSTS) {
    run('INSERT INTO posts (user_id, title, body, tags, status, ai_score, likes, comments, views, revenue, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)', uid(ext), title, body, JSON.stringify(tags), st, 92, likes, comments, views, r2(likes * 0.05 + comments * 0.1 + views * 0.001), new Date(Date.now() - Math.random() * 20 * 86400_000).toISOString());
  }
  return true;
}
